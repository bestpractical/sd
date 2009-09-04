package App::SD::Replica::lighthouse::PushEncoder;
use Any::Moose;
use Params::Validate;
use Path::Class;

has sync_source => (
    isa => 'App::SD::Replica::lighthouse',
    is  => 'rw',
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
        elsif ( $change->record_type eq 'attachment'
            and $change->change_type eq 'add_file' )
        {
            $id = $self->integrate_attachment( $change, $changeset );
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

    # Figure out the remote site's ticket ID for this change's record
    my $remote_ticket_id =
      $self->sync_source->remote_id_for_uuid( $change->record_uuid );
    my $ticket = $self->sync_source->lighthouse->ticket;
    $ticket->load( $remote_ticket_id );
    my $attr = $self->_recode_props_for_integrate($change);
    $ticket->update(
        map { $_ => $attr->{$_} }
          grep { exists $attr->{$_} }
          qw/title body state assigned_user_id milestone_id tag/
    );
    return $remote_ticket_id;
}

sub integrate_comment {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Figure out the remote site's ticket ID for this change's record

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my $ticket_id = $self->sync_source->remote_id_for_uuid( $props{'ticket'} );
    my $ticket = $self->sync_source->lighthouse->ticket;
    $ticket->load( $ticket_id );

    my %content = ( body => $props{'content'} || '' );

    $ticket->update(%content);
    return $ticket_id;
}

sub integrate_ticket_attachment {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );
    my %props     = map { $_->name => $_->new_value } $change->prop_changes;
    my $ticket_id = $self->sync_source->remote_id_for_uuid( $props{'ticket'} );

    $self->sync_source->log(
        'Warn: Net::Lighthouse does *not* support attachment yet');
    return $ticket_id;
}

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Build up a ticket object out of all the record's attributes
    my $ticket = $self->sync_source->lighthouse->ticket;
    my $attr = $self->_recode_props_for_integrate($change);
    $ticket->create(
        map { $_ => $attr->{$_} }
          grep { exists $attr->{$_} }
          qw/title body state assigned_user_id milestone_id tag/
    );
    return $ticket->number;
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        if ( $key eq 'summary' ) {
            $attr{title} = $props{$key};
        }
        elsif ( $key eq 'status' ) {
            $attr{state} = $props{$key};
        }
        elsif ( $key eq 'tag' ) {
            $attr{tag} = $props{$key};
        }
        elsif ( $key eq 'content' ) {
            $attr{body} = $props{$key};
        }
        elsif ( $key eq 'milestone' ) {
            my $milestone = $self->sync_source->lighthouse->milestone;
            if ( $props{$key} ) {
                eval { $milestone->load( $props{$key} ) };
                if ( $@ ) {
                    $self->sync_source->log(
                        "Warn: no milestone $props{$key} exist");
                }
                else {
                    $attr{milestone_id} = $milestone->id;
                }
            }
            else {
                $attr{milestone_id} = undef,
            }
        }
        elsif ( $key eq 'owner' ) {
            if ( $props{key} ) {
                if ( $props{$key} =~ /\((\d+)\)/ ) {
                    $attr{assigned_user_id} = $1;
                }
            }
            else {
                $attr{assigned_user_id} = undef;
            }
        }
        else {
            $attr{$key} = $props{$key};
        }
    }
    $attr{body} ||= '';
    return \%attr;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
