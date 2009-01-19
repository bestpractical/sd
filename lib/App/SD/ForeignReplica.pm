package App::SD::ForeignReplica;
use Moose;
use Params::Validate;

extends 'Prophet::ForeignReplica';


=head2 integrate_change $change $changeset

Given a change (and the changeset it's part of), this routine will load
the push encoder for the foreign replica's type and call integrate_change
on it.

To avoid publishing prophet-private data, It skips any change with a record type
that record_type starts with '__'.

This is probably a bug.

=cut

sub integrate_change {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # don't push internal records
    return if $change->record_type =~ /^__/;

    Prophet::App->require( $self->push_encoder());
    my $recoder = $self->push_encoder->new( { sync_source => $self } );
    $recoder->integrate_change($change,$changeset);
}



=head2 record_pushed_transaction $foreign_transaction_id, $changeset

Record that this replica was the original source of $foreign_transaction_id (with changeset $changeset)

=cut

sub record_pushed_transaction {
    my $self = shift;
    my %args = validate( @_,
        { transaction => 1, changeset => { isa => 'Prophet::ChangeSet' }, record => 1 } );

    $self->state_handle->store_local_metadata(
        "foreign-txn-from-".$self->uuid . '-record-'.$args{record}. '-txn-' . $args{transaction} => 
        join( ':',
            $args{changeset}->original_source_uuid,
            $args{changeset}->original_sequence_no )
    );
}

=head2 foreign_transaction_originated_locally $transaction_id $foreign_record_id

Given an transaction id, will return true if this transaction originated in Prophet 
and was pushed to RT or originated in RT and has already been pulled to the prophet replica.


This is a mapping of all the transactions we have pushed to the
remote replica we'll only ever care about remote sequence #s greater
than the last transaction # we've pulled from the remote replica
once we've done a pull from the remote replica, we can safely expire
all records of this type for the remote replica (they'll be
obsolete)

We use this cache to avoid integrating changesets we've pushed to the 
remote replica when doing a subsequent pull

=cut

sub foreign_transaction_originated_locally {
    my $self = shift;
    my ($id, $record) = validate_pos( @_, 1, 1);
    return $self->state_handle->fetch_local_metadata("foreign-txn-from-". $self->uuid .'-record-'.$record. '-txn-' .$id );
}

sub traverse_changesets {
    my $self = shift;
    my %args = validate( @_,
        {   after    => 1,
            callback => 1,
        }
    );

    Prophet::App->require( $self->pull_encoder());
    my $recoder = $self->pull_encoder->new( { sync_source => $self } );
    $recoder->run(after => $args{'after'}, callback => $args{'callback'});

}

sub remote_uri_path_for_id {
    die "your subclass needds to implement this to be able to map a remote id to /ticket/id or soemthing";

}

=head2 uuid_for_remote_id $id

lookup the uuid for the remote record id. If we don't find it, 
construct it out of the remote url and the remote uri path for the record id;

=cut


sub uuid_for_remote_id {
    my ( $self, $id ) = @_;


    return $self->_lookup_uuid_for_remote_id($id)
        || $self->uuid_for_url( $self->remote_url . $self->remote_uri_path_for_id($id) );
}

sub _lookup_uuid_for_remote_id {
    my $self = shift;
    my ($id) = validate_pos( @_, 1 );



    return $self->state_handle->fetch_local_metadata('local_uuid_for_'.  
        $self->uuid_for_url( $self->remote_url . $self->remote_uri_path_for_id($id))
    );
}

sub _set_uuid_for_remote_id {
    my $self = shift;
    my %args = validate( @_, { uuid => 1, remote_id => 1 } );
    return $self->state_handle->store_local_metadata('local_uuid_for_'.
        $self->uuid_for_url(
                  $self->remote_url
                . $self->remote_uri_path_for_id( $args{'remote_id'} )
        ),
        $args{uuid}
    );
}

# This mapping table stores uuids for tickets we've synced from a remote database
# Basically, if we created the ticket to begin with, then we'll know its uuid
# if we pulled the ticket from the foreign replica then its uuid will be generated
# based on a UUID-from-ticket-url scheme

sub remote_id_for_uuid {
    my ( $self, $uuid_or_luid ) = @_;

    require App::SD::Model::Ticket;
    my $ticket = App::SD::Model::Ticket->new(
        app_handle => $self->app_handle,
        type   => 'ticket'
    );
    $ticket->load( $uuid_or_luid =~ /^\d+$/? 'luid': 'uuid', $uuid_or_luid )
        or do {
            warn "couldn't load ticket #$uuid_or_luid";
            return undef
        };

    my $prop = $self->uuid . '-id';
    my $id = $ticket->prop( $prop )
        or warn "ticket #$uuid_or_luid has no property '$prop'";
    return $id;
}

sub _set_remote_id_for_uuid {
    my $self = shift;
    my %args = validate(
        @_,
        {   uuid      => 1,
            remote_id => 1
        }
    );

    require App::SD::Model::Ticket;
    my $ticket = App::SD::Model::Ticket->new(
        app_handle => $self->app_handle,
        type   => 'ticket'
    );
    $ticket->load( uuid => $args{'uuid'} );
    $ticket->set_props( props => { $self->uuid.'-id' => $args{'remote_id'} } );

}


=head2 record_remote_id_for_pushed_record

When pushing a record created within the prophet cloud to a foreign replica, we
need to do bookkeeping to record the prophet uuid to remote id mapping.

=cut


sub record_remote_id_for_pushed_record {
    my $self = shift;
    my %args = validate(
        @_,
        {   uuid      => 1,
            remote_id => 1
        }
    );
    $self->_set_uuid_for_remote_id(%args);
    $self->_set_remote_id_for_uuid(%args);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
