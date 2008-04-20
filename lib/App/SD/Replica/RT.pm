use warnings;
use strict;

package App::SD::Replica::RT;
use base qw/Prophet::ForeignReplica/;
use Params::Validate qw(:all);
use UNIVERSAL::require;
use RT::Client::REST       ();
use RT::Client::REST::User ();
use RT::Client::REST::Ticket;
use Memoize;
use Prophet::ChangeSet;
use App::SD::Replica::RT::PullEncoder;

use constant scheme => 'rt';

__PACKAGE__->mk_accessors(qw/rt rt_url rt_queue rt_query/);


=head1 NOTES ON PUSH

If the remote storage (RT) can not represent a whole changeset along with the prophet changeset uuid, then we need to 
create a seperate locally(?) stored map of:
    remote-subchangeset-identifier to changeset uuid.
    remote id to prophet record uuid
    

For each sync of the same remote source (RT), we need a unique prophet database domain.

if clkao syncs from RT, jesse can sync with clkao but not with RT directly with the same database.








Push to rt algorithm

apply a single changeset that's part of the push:
    - for each record in that changeset:
        - pull the record's txn list from the server
        - for each txn we don't know we've already seen, look at it
            - if it is from the changeset we just pushed, then
                store the id of the new transaction and originating uuid in the push-ticket store.
                    - does that let us specify individual txns? or is it a high-water mark?
             - if it is _not_ from the changeset we just pushed, then 
                do we just ignore it?
                how do we mark an out-of-order transaction as not-pulled?
                


Changesets we want to push from SD to RT and how they map

    
what do we do with cfs rt doesn't know about?



SD::Source::RT->recode_ticket



=cut

=head2 setup

Open a connection to the SVN source identified by C<$self->url>.

=cut

use File::Temp 'tempdir';

sub setup {
    my $self = shift;
    my ( $server, $type, $query ) = $self->{url} =~ m/^(.*?)\|(.*?)\|(.*)$/
        or die "Can't parse rt server spec";
    my $uri = URI->new($server);
    my ( $username, $password );
    if ( my $auth = $uri->userinfo ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }
    $self->rt_url("$uri");
    $self->rt_queue($type);
    $self->rt_query( $query . " AND Queue = '$type'" );
    $self->rt( RT::Client::REST->new( server => $server ) );

    ( $username, $password ) = $self->prompt_for_login( $uri, $username ) unless $password;

    $self->rt->login( username => $username, password => $password );

        $self->SUPER::setup(@_);

}

sub record_pushed_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, changeset => { isa => 'Prophet::ChangeSet' } } );

    for my $txn (
        reverse RT::Client::REST::Ticket->new(
            rt => $self->rt,
            id => $args{'ticket'}
        )->transactions->get_iterator->()
        )
    {
        last if $txn->id <= $self->last_changeset_from_source( $args{changeset}->original_source_uuid );
        $self->record_pushed_transaction( transaction => $txn->id, changeset => $args{'changeset'} );
    }
}

=head2 prophet_has_seen_transaction $transaction_id

Given an transaction id, will return true if this transaction originated in Prophet 
and was pushed to RT or originated in RT and has already been pulled to the prophet replica.

=cut

# This is a mapping of all the transactions we have pushed to the
# remote replica we'll only ever care about remote sequence #s greater
# than the last transaction # we've pulled from the remote replica
# once we've done a pull from the remote replica, we can safely expire
# all records of this type for the remote replica (they'll be
# obsolete)

# we use this cache to avoid integrating changesets we've pushed to the remote replica when doing a subsequent pull

my $TXN_METATYPE = 'txn-source';

sub _txn_storage {
    my $self = shift;
    return $self->state_handle->metadata_storage( $TXN_METATYPE, 'prophet-txn-source' );
}

sub prophet_has_seen_transaction {
    my $self = shift;
    my ($id) = validate_pos( @_, 1 );
    return $self->_txn_storage->( $self->uuid . '-txn-' . $id );
}

sub record_pushed_transaction {
    my $self = shift;
    my %args = validate( @_, { transaction => 1, changeset => { isa => 'Prophet::ChangeSet' } } );

    $self->_txn_storage->(
        $self->uuid . '-txn-' . $args{transaction},
        join( ':', $args{changeset}->original_source_uuid, $args{changeset}->original_sequence_no )
    );
}

# This cache stores uuids for tickets we've synced from a remote RT
# Basically, if we created the ticket to begin with, then we'll know its uuid
# if we pulled the ticket from RT then its uuid will be generated based on a UUID-from-ticket-url scheme
# This cache is PERMANENT. - aka not a cache but a mapping table

sub remote_id_for_uuid {
    my ( $self, $uuid_for_remote_id ) = @_;

    # XXX: should not access CLI handle
    my $ticket = Prophet::Record->new( handle => Prophet::CLI->new->handle, type => 'ticket' );
    $ticket->load( uuid => $uuid_for_remote_id );
    return $ticket->prop( $self->uuid . '-id' );
}

sub uuid_for_remote_id {
    my ( $self, $id ) = @_;
    return $self->_lookup_remote_id($id) || $self->uuid_for_url( $self->rt_url . "/ticket/$id" );
}

sub _lookup_remote_id {
    my $self = shift;
    my ($id) = validate_pos( @_, 1 );

    return $self->_remote_id_storage( $self->uuid_for_url( $self->rt_url . "/ticket/$id" ) );
}

sub _set_remote_id {
    my $self = shift;
    my %args = validate(
        @_,
        {   uuid      => 1,
            remote_id => 1
        }
    );
    return $self->_remote_id_storage( $self->uuid_for_url( $self->rt_url . "/ticket/" . $args{'remote_id'} ),
        $args{uuid} );
}

sub record_pushed_ticket {
    my $self = shift;
    my %args = validate(
        @_,
        {   uuid      => 1,
            remote_id => 1
        }
    );
    $self->_set_remote_id(%args);
}

sub _integrate_change {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );
    my $id;
    eval {
        if ( $change->record_type eq 'ticket' and $change->change_type eq 'add_file' )
        {
            $id = $self->integrate_ticket_create( $change, $changeset );
            $self->record_pushed_ticket( uuid => $change->record_uuid, remote_id => $id );

        } elsif ( $change->record_type eq 'comment' ) {

            $id = $self->integrate_comment( $change, $changeset );
        } elsif ( $change->record_type eq 'ticket' ) {
            $id = $self->integrate_ticket_update( $change, $changeset );

        } else {
            return undef;
        }

        $self->record_pushed_transactions( ticket => $id, changeset => $changeset );

    };
    warn $@ if $@;
    return $id;
}

sub integrate_ticket_update {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );

    # Figure out the remote site's ticket ID for this change's record
    my $remote_ticket_id = $self->remote_id_for_uuid( $change->record_uuid );
    my $ticket           = RT::Client::REST::Ticket->new(
        rt => $self->rt,
        id => $remote_ticket_id,
        %{ $self->_recode_props_for_integrate($change) }
    )->store();

    return $remote_ticket_id;
}

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );

    # Build up a ticket object out of all the record's attributes
    my $ticket = RT::Client::REST::Ticket->new(
        rt    => $self->rt,
        queue => $self->rt_queue(),
        %{ $self->_recode_props_for_integrate($change) }
    )->store( text => "Not yet pulling in ticket creation comment" );

    return $ticket->id;
}

sub integrate_comment {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    # Figure out the remote site's ticket ID for this change's record

    my %props = map { $_->name => $_->new_value } $change->prop_changes;

    my $id     = $self->remote_id_for_uuid( $props{'ticket'} );
    my $ticket = RT::Client::REST::Ticket->new(
        rt => $self->rt,
        id => $id
    );
    if ( $props{'type'} eq 'comment' ) {
        $ticket->comment( message => $props{'content'} );
    } else {
        $ticket->correspond( message => $props{'content'} );

    }
    return $id;
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        next unless ( $key =~ /^(summary|queue|status|owner|custom)/ );
        if ( $key =~ /^custom-(.*)/ ) {
            $attr{cf}->{$1} = $props{$key};
        } elsif ( $key eq 'summary' ) {
            $attr{'subject'} = $props{summary};
        } else {
            $attr{$key} = $props{$key};
        }
    }
    return \%attr;
}

=head2 uuid

Return the replica SVN repository's UUID

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_for_url( join( '/', $self->rt_url, $self->rt_query ) );

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

    my $recoder = App::SD::Replica::RT::PullEncoder->new( { sync_source => $self } );
    for my $id ( $self->find_matching_tickets ) {

        # XXX: _recode_transactions should ignore txn-id <= $first_rev
        $args{callback}->($_)
            for @{
            $recoder->run(
                ticket => $self->rt->show( type => 'ticket', id => $id ),
                transactions => $self->find_matching_transactions( ticket => $id, starting_transaction => $first_rev )
            )
            };
    }
}

sub find_matching_tickets {
    my $self = shift;
    return $self->rt->search( type => 'ticket', query => $self->rt_query );
}

sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, starting_transaction => 1 } );
    my @txns;
    for my $txn ( sort $self->rt->get_transaction_ids( parent_id => $args{ticket} ) ) {
        next if $txn < $args{'starting_transaction'};        # Skip things we've pushed
        next if $self->prophet_has_seen_transaction($txn);
        push @txns, $self->rt->get_transaction( parent_id => $args{ticket}, id => $txn, type => 'ticket' );
    }
    return \@txns;
}

1;
