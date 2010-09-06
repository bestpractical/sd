package App::SD::Replica::redmine;
use Any::Moose;

extends 'App::SD::ForeignReplica';

use constant scheme => 'redmine';
use constant pull_encoder => 'App::SD::Replica::redmine::PullEncoder';
use constant push_encoder => 'App::SD::Replica::redmine::PushEncoder';
use Prophet::ChangeSet;

has remote_url => ( isa => 'Str', is => 'rw');
has query => ( isa => 'Str', is => 'rw');

has redmine => (isa => 'Net::Redmine', is => 'rw');

use URI;

sub BUILD {
    my $self = shift;

    eval {
        require Net::Redmine;
    };
    if ($@) {
        die "SD requires Net::Redmine to sync with a Redmine server.\n".
        "'cpan Net::Redmine' may sort this out for you";
    }



    my ( $server, $type, $query ) = $self->{url} =~ m/^redmine:(.*?)$/
        or die "Can't parse Redmine server spec. Expected something like redmine:http://example.com/projects/project_name\n";

    my $uri = URI->new($server);
    my ( $username, $password );
    if ( my $auth = $uri->userinfo ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }

    $self->remote_url( $uri->as_string );

    ($username, $password)
        = $self->prompt_for_login(
            uri      => $uri,
            username => $username,
        ) unless $password;

    $self->redmine(
        Net::Redmine->new(
            url      => $self->remote_url,
            user     => $username,
            password => $password
        ));

}

sub record_pushed_transactions {}

sub _uuid_url {
    my $self = shift;
    Carp::cluck "- can't make a uuid for this" unless ($self->remote_url);
    return $self->remote_url;
}

sub remote_uri_path_for_id {
    my $self = shift;
    my $id = shift;
    return "/issues/show/".$id;
}

1;
