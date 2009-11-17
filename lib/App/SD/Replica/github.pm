package App::SD::Replica::github;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use Memoize;

use URI;
use Memoize;
use Net::GitHub;

use Prophet::ChangeSet;

use constant scheme => 'github';
use constant pull_encoder => 'App::SD::Replica::github::PullEncoder';
use constant push_encoder => 'App::SD::Replica::github::PushEncoder';

has github     => ( isa => 'Net::GitHub::V2', is => 'rw' );
has remote_url => ( isa => 'Str',             is => 'rw' );
has owner      => ( isa => 'Str',             is => 'rw' );
has repo       => ( isa => 'Str',             is => 'rw' );
has query      => ( isa => 'Str',             is => 'rw' );

our %PROP_MAP = ( state => 'status', title => 'summary' );

sub BUILD {
    my $self = shift;

    my ( $server, $owner, $repo ) =
      $self->{url} =~ m{^github:(http://.*?github.com/)?(.*?)/([^/]+)/?}
      or die
        "Can't parse Github server spec. Expected github:owner/repository or\n"
        ."github:http://github.com/owner/repository.";

    my ( $uri, $username, $api_token );

    if ($server) {
        $uri = URI->new($server);
        if ( my $auth = $uri->userinfo ) {
            ( $username, $api_token ) = split /:/, $auth, 2;
            $uri->userinfo(undef);
        }
    }
    else {
        $uri = 'http://github.com/';
    }

    ( $username, $api_token )
        = $self->prompt_for_login(
            uri => $uri,
            username => $username,
            secret_prompt => sub {
                my ($uri, $username) = @_;
                return "GitHub API token for $username (from ${uri}account): ";
            },
        ) unless $api_token;

    $self->remote_url("$uri");
    $self->owner( $owner );
    $self->repo( $repo );

    $self->github(
        Net::GitHub->new(
            login => $username,
            token => $api_token,
            repo  => $repo,
            owner => $owner,
        ) );
}

sub record_pushed_transactions {}

sub uuid {
    my $self = shift;
    Carp::cluck "- can't make a uuid for this" unless ($self->remote_url && $self->owner && $self->repo );
    return $self->uuid_for_url( join( '/', $self->remote_url, $self->owner , $self->repo ) );
}

sub remote_uri_path_for_comment {
    my $self = shift;
    my $id = shift;
    return "/comment/".$id;
}

sub remote_uri_path_for_id {
    my $self = shift;
    my $id = shift;
    return "/ticket/".$id;
}

sub database_settings {
    my $self = shift;
    return {
# TODO limit statuses too? the problem is github's statuses are so poor,
# it only has 2 statuses: 'open' and 'closed'.
        project_name => $self->owner . '/' . $self->repo,
    };

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
