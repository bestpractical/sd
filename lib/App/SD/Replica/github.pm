package App::SD::Replica::github;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use Memoize;

use UNIVERSAL::require;
use URI;
use Memoize;

use Prophet::ChangeSet;

use constant scheme => 'github';
use constant pull_encoder => 'App::SD::Replica::github::PullEncoder';
use constant push_encoder => 'App::SD::Replica::github::PushEncoder';

has github     => ( isa => 'Net::Github', is => 'rw' );
has remote_url => ( isa => 'Str',         is => 'rw' );
has owner      => ( isa => 'Str',         is => 'rw' );
has repo       => ( isa => 'Str',         is => 'rw' );


sub BUILD {
    my $self = shift;
    use Net::Github;

    my ( $server , $owner , $repo  ) = $self->{url} =~ m/^github:(.+?)\|(\w+)\|(\w+)\|$/
        or die "Can't parse Github server spec. Expected github:http://user\@github.com|owner|repository|";


    my $uri = URI->new($server);
    my ( $username, $apikey );
    if ( my $auth = $uri->userinfo ) {
        ( $username, $apikey ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }

    ( $username, $apikey ) = $self->prompt_for_login( $uri, $username ) unless $apikey ;

    $self->remote_url("$uri");
    $self->owner( $owner );
    $self->repo( $repo );

    $self->github(
        Net::GitHub->new(
            login => $username,
            token => $apikey,
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



__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
