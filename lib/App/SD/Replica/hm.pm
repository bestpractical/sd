package App::SD::Replica::hm;
use Moose;
extends 'App::SD::ForeignReplica';
use Params::Validate qw(:all);
use UNIVERSAL::require;
use URI;
use Memoize;
use Prophet::ChangeSet;
use File::Temp 'tempdir';

has hm => ( isa => 'Net::Jifty', is => 'rw');
has remote_url => ( isa => 'Str', is => 'rw');
has hm_username => ( isa => 'Str', is => 'rw');
has props => ( isa => 'HashRef[Str]', is => 'rw');

use constant scheme => 'hm';
use App::SD::Replica::rt;


=head2 setup

Open a connection to the SVN source identified by C<$self->url>.

=cut

# XXX: this should be called from superclass, or better, have individual attributes have their own builders.

sub BUILD {
    my $self = shift;
    require Net::Jifty;
    my ($server, $props) = $self->{url} =~ m/^hm:(.*?)(?:\|(.*))?$/
        or die "Can't parse Hiveminder server spec. Expected hm:http://hiveminder.com or hm:http://hiveminder.com|props";
    $self->url($server);
    my $uri = URI->new($server);
    my ( $username, $password );
    if ( $uri->can('userinfo') && (my $auth = $uri->userinfo) ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }
    $self->remote_url("$uri");
    $self->hm_username($username);
    ( $username, $password ) = $self->prompt_for_login( $uri, $username ) unless $password;
    if ( $props ) {
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
    Carp::cluck "- can't make a uuid for this" unless ($self->remote_url && $self->hm_username);
    return $self->uuid_for_url( join( '/', $self->remote_url, $self->hm_username ) );
}

sub traverse_changesets {
    my $self = shift;
    my %args = validate(
        @_,
        {   after    => 1,
            callback => 1,
        }
    );

    my $first_rev = ( $args{'after'} + 1 ) || 1;

    require App::SD::Replica::hm::PullEncoder;
    my $recoder = App::SD::Replica::hm::PullEncoder->new( { sync_source => $self } );
    for my $task ( @{ $self->find_matching_tasks } ) {
        my $changesets = $recoder->run(
            task         => $task,
            transactions => $self->find_matching_transactions(
                task => $task->{id}, starting_transaction => $first_rev
            ),
        );
        $args{'callback'}->($_) for @$changesets;
    }
}

sub find_matching_tasks {
    my $self = shift;
    my %args = ();

    if ( my $props = $self->props ) {
        while ( my ($k, $v) = each %$props ) { $args{$k} = $v }
    }

    unless ( keys %args ) {
        %args = (
            owner        => 'me',
            group        => 0,
            requestor    => 'me',
            not_complete => 1,
        );
    }

    my $status = $self->hm->act( 'TaskSearch', %args );
    unless ( $status->{'success'} ) {
        die "couldn't search";
    }
    return $status->{content}{tasks};
}

sub record_pushed_transaction {

    # don't need this for hm
}

# hiveminder transaction ~= prophet changeset
# hiveminder taskhistory ~= prophet change
# hiveminder taskemail ~= prophet change
sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { task => 1, starting_transaction => 1 } );

    my $txns = $self->hm->search( 'TaskTransaction', task_id => $args{task} ) || [];
    my @matched;
    for my $txn (@$txns) {
        next if $txn->{'id'} < $args{'starting_transaction'};    # Skip things we've pushed

        next if $self->prophet_has_seen_transaction( $txn->{'id'} );

        $txn->{history_entries} = $self->hm->search( 'TaskHistory', transaction_id => $txn->{'id'} );
        $txn->{email_entries}   = $self->hm->search( 'TaskEmail',   transaction_id => $txn->{'id'} );
        push @matched, $txn;
    }
    return \@matched;

}

sub user_info {
    my $self = shift;
    my %args = @_;
    return $self->_user_info(
        keys %args? (%args) : (email => $self->hm_username)
    );
}

sub _user_info {
    my $self = shift;
    my %args = @_;
    my $status = $self->hm->act(
        'SearchUser', %args,
    );
    die $status->{'error'} unless $status->{'success'};
    return $status->{'content'}{'search'}[0] || {};
}
memoize '_user_info';

sub _integrate_change {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # don't push internal records
    return if $change->record_type =~ /^__/;

    require App::SD::Replica::hm::PushEncoder;
    my $recoder = App::SD::Replica::hm::PushEncoder->new( { sync_source => $self } );
    $recoder->integrate_change($change,$changeset);
}

sub remote_uri_path_for_id {
    my $self = shift;
    my $id = shift;
    return "/task/".$id;
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
while ( my ($k, $v) = each %PROP_MAP ) {
    if ( $REV_PROP_MAP{ $v } ) {
        $REV_PROP_MAP{ $v } = [ $REV_PROP_MAP{ $v } ]
            unless ref $REV_PROP_MAP{ $v };
        push @{ $REV_PROP_MAP{ $v } }, $k;
    } else {
        $REV_PROP_MAP{ $v } = $k;
    }
}

sub property_map {
    my $self = shift;
    my $dir = shift || 'pull';
    if ( $dir eq 'pull' ) {
        return %PROP_MAP;
    }
    elsif ( $dir eq 'push' ) {
        return %REV_PROP_MAP;
    }
    else {
        die "unknown direction";
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
