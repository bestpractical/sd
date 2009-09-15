package App::SD::Replica::redmine::PushEncoder;

use Any::Moose;
use Params::Validate;

has sync_source => (
    isa => 'App::SD::Replica::redmine',
    is  => 'rw',
    required => 1
);

sub integrate_change {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );
    my ( $id, $record );

    return
      if $self->sync_source->app_handle->handle->last_changeset_from_source(
        $changeset->original_source_uuid ) >= $changeset->original_sequence_no;

    my $before_integration = time();

    eval {
        if (    $change->record_type eq 'ticket'
            and $change->change_type eq 'add_file' )
        {
            $id = $self->integrate_ticket_create( $change, $changeset );
            $self->sync_source->record_remote_id_for_pushed_record(
                uuid      => $change->record_uuid,
                remote_id => $id,
            );
        }
        elsif ( $change->record_type eq 'comment'
            and $change->change_type eq 'add_file' )
        {
            $id = $self->integrate_comment( $change, $changeset );
        }
        elsif ( $change->record_type eq 'ticket' ) {
            $id = $self->integrate_ticket_update( $change, $changeset );
        }
        else {
            $self->sync_source->log(
                'I have no idea what I am doing for ' . $change->record_uuid );
            return;
        }

        $self->sync_source->record_pushed_transactions(
            start_time => $before_integration,
            ticket     => $id,
            changeset  => $changeset,
        );
    };

    if ( my $err = $@ ) {
        $self->sync_source->log( "Push error: " . $err );
    }

    return $id;
}

sub integrate_ticket_update {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );
    my $remote_ticket_id
        = $self->sync_source->remote_id_for_uuid( $change->record_uuid );
    my $attr = $self->_recode_props_for_integrate($change);

    my $ticket = Net::Redmine::Ticket->load(
        connection => $self->sync_source->redmine->connection,
        id         => $remote_ticket_id
    );
    for (qw/subject description /) {
        $ticket->$_( $attr->{$_} ) if $attr->{$_};
    }
    if ( $attr->{state} ) {
        $ticket->status("Open")  if $attr->{state} eq 'open';
        $ticket->status("Closed") if $attr->{state} eq 'closed';
    }
    $ticket->save;
    return $remote_ticket_id;
}

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );
    my $attr = $self->_recode_props_for_integrate($change);
    my $ticket = $self->sync_source->redmine->create(ticket => $attr);
    # TODO error
    return $ticket->{id};
}

sub integrate_comment {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my $ticket_id
        = $self->sync_source->remote_id_for_uuid( $props{'ticket'} );
    my $ticket = Net::Redmine::Ticket->load(
        connection => $self->sync_source->redmine->connection,
        id         => $ticket_id
    );
    $ticket->description( $props{'content'} );
    $ticket->save;
    return $ticket_id;
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        if ( $key eq 'summary' ) {
            $attr{subject} = $props{$key};
        }
        elsif ( $key eq 'body' ) {
            $attr{description} = $props{$key};
        }
        elsif ( $key eq 'status' ) {
            $attr{state} = $props{$key} =~ /new|open/ ? 'open' : 'closed';
        }
    }
    return \%attr;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
