package App::SD::Replica::hm;
use Any::Moose;
extends 'App::SD::ForeignReplica';
use Params::Validate qw(:all);
use URI;
use Memoize;
use Prophet::ChangeSet;
use File::Temp 'tempdir';

has hm               => ( isa => 'Net::Jifty', is => 'rw' );
has remote_url       => ( isa => 'Str',        is => 'rw' );
has foreign_username => ( isa => 'Str',        is => 'rw' );
has props            => ( isa => 'HashRef',    is => 'rw' );

use constant scheme       => 'hm';
use constant pull_encoder => 'App::SD::Replica::hm::PullEncoder';
use constant push_encoder => 'App::SD::Replica::hm::PushEncoder';

# XXX TODO - kill the query requirement by refactoring sub run in the superclass
use constant query => '';

=head2 BUILD

Open a connection to the source identified by C<$self->{url}>.

=cut

# XXX: this should be called from superclass, or better, have individual attributes have their own builders.

sub BUILD {
    my $self = shift;
    require Net::Jifty;
    my ( $server, $props ) = $self->{url} =~ m/^hm:(.*?)(?:\|(.*))?$/
        or die
        "Can't parse Hiveminder server spec. Expected hm:http://hiveminder.com or hm:http://hiveminder.com|props";
    $self->url($server);
    my $uri = URI->new($server);
    my ( $username, $password );
    if ( $uri->can('userinfo') && ( my $auth = $uri->userinfo ) ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }
    $self->remote_url("$uri");
    $self->foreign_username($username) if ($username);

    ( $username, $password )
        = $self->prompt_for_login(
            uri      => $uri,
            username => $username,
        ) unless $password;

    if ($props) {
        my %props = split /=|;/, $props;
        $self->props( \%props );
    }
    $self->hm(
        Net::Jifty->new(
            site        => $self->remote_url,
            cookie_name => 'JIFTY_SID_HIVEMINDER',

            email    => $username,
            password => $password
        )
    );
}

=head2 uuid

Return the replica's UUID

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_for_url( join( '/', $self->remote_url, $self->foreign_username ) );
}

sub get_txn_list_by_date {
    my $self   = shift;
    my $ticket = shift;
    my @txns   = map {
        my $txn_created_dt = App::SD::Util::string_to_datetime( $_->{modified_at} );
        unless ($txn_created_dt) {
            die "Couldn't parse '" . $_->{modified_at} . "' as a timestamp";
        }
        my $txn_created = $txn_created_dt->epoch;

        return { id => $_->{id}, creator => $_->{creator}, created => $txn_created }
        }

        sort { $a->{'id'} <=> $b->{'id'} }
        @{ $self->hm->search( 'TaskTransaction', task_id => $ticket ) || [] };

    return @txns;
}

sub user_info {
    my $self = shift;
    my %args = @_;
    return $self->_user_info( keys %args ? (%args) : ( email => $self->foreign_username ) );
}

sub _user_info {
    my $self   = shift;
    my $key = shift;
    my $value = shift;
    return undef unless defined $value;
    my $status = $self->hm->search('User', $key => $value);
    die $status->{'error'} unless $status->[0]->{'id'};
    return $status->[0];
}
memoize '_user_info';

sub remote_uri_path_for_id {
    my $self = shift;
    my $id   = shift;
    return "/task/" . $id;
}

our %PROP_MAP = (
    owner_id                 => 'owner',
    requestor_id             => 'reporter',
    priority                 => 'priority_integer',
    completed_at             => 'completed',
    due                      => 'due',
    creator                  => 'creator',
    milestone                => '_delete',
    attachment_count         => '_delete',
    depended_on_by_count     => '_delete',
    depended_on_by_summaries => '_delete',
    depends_on_count         => '_delete',
    depends_on_summaries     => '_delete',
    group_id                 => '_delete',
    last_repeat              => '_delete',
    repeat_days_before_due   => '_delete',
    repeat_every             => '_delete',
    repeat_of                => '_delete',
    repeat_next_create       => '_delete',
    repeat_period            => '_delete',
    repeat_stacking          => '_delete',

);

our %REV_PROP_MAP = ();
while ( my ( $k, $v ) = each %PROP_MAP ) {
    if ( $REV_PROP_MAP{$v} ) {
        $REV_PROP_MAP{$v} = [ $REV_PROP_MAP{$v} ]
            unless ref $REV_PROP_MAP{$v};
        push @{ $REV_PROP_MAP{$v} }, $k;
    } else {
        $REV_PROP_MAP{$v} = $k;
    }
}

sub property_map {
    my $self = shift;
    my $dir = shift || 'pull';
    if ( $dir eq 'pull' ) {
        return %PROP_MAP;
    } elsif ( $dir eq 'push' ) {
        return %REV_PROP_MAP;
    } else {
        die "unknown direction";
    }
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
