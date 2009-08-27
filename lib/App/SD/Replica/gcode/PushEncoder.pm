package App::SD::Replica::gcode::PushEncoder;
use Any::Moose;
use Params::Validate;
use Net::Google::Code::Issue;
use Net::Google::Code;

has sync_source => (
    isa => 'App::SD::Replica::gcode',
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

# if the original_sequence_no of this changeset is <=
# the last changeset our sync source for the original_sequence_no, we can skip it.
# XXX TODO - this logic should be at the changeset level, not the cahnge level, as it applies to all
# changes in the changeset
#    warn $self->sync_source->app_handle->handle->last_changeset_from_source(
#        $changeset->original_source_uuid ), "\n";
    return
      if $self->sync_source->app_handle->handle->last_changeset_from_source(
        $changeset->original_source_uuid ) >= $changeset->original_sequence_no;

    my $before_integration = time();
    my ( $email, $password );
    if ( !$self->sync_source->gcode->password ) {
        ( $email, $password )
            = $self->sync_source->prompt_for_login(
                uri => 'gcode:' . $self->sync_source->project,
            );
        $self->sync_source->gcode->email($email);
        $self->sync_source->gcode->password($password);
    }

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
    my $ticket = $self->sync_source->gcode->issue();
    $ticket->load($remote_ticket_id);
    $ticket->update( %{ $self->_recode_props_for_integrate($change) }, );
    return $remote_ticket_id;
}

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Build up a ticket object out of all the record's attributes
    my $ticket = $self->sync_source->gcode->issue;
    my $id =
      $ticket->create( %{ $self->_recode_props_for_integrate($change) } );

    return $id;
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
    my $ticket = $self->sync_source->gcode->issue( id => $ticket_id );

    my %content = ( comment => $props{'content'}, );

    $ticket->update(%content);
    return $ticket_id;
}

sub integrate_attachment {
    my ( $self, $change, $changeset ) = validate_pos(
        @_,
        { isa => 'App::SD::Replica::gcode::PushEncoder' },
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    my %props     = map { $_->name => $_->new_value } $change->prop_changes;
    my $ticket_id = $self->sync_source->remote_id_for_uuid( $props{'ticket'} );
    my $ticket    = $self->sync_source->gcode->issue( id => $ticket_id, );

    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    my $file = File::Spec->catfile( $tempdir, ( $props{'name'} || 'unnamed' ) );
    open my $fh, '>', $file or die $!;
    print $fh $props{content};
    close $fh;
    my %content = ( comment => '(See attachments)', files => ["$file"] );
    $ticket->update(%content);
    return $ticket_id;
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        if ( $key =~ /^(summary|owner|cc|blocked_on)/ ) {
            $attr{$key} = $props{$key};
        }
        elsif ( $key eq 'status' ) {
            $attr{$key} = ucfirst $props{$key};
        }
        elsif ( $key eq 'merged_into' ) {
        # yeah, the comment form use 'merge_into' name
            $attr{merge_into} = $props{$key};
        }
        elsif ( $key eq 'tags' ) {
            $attr{labels} ||= [];
            push @{$attr{labels}}, split /\s*,\s*/, $props{$key};
        }
        else {
            $attr{labels} ||= [];
            push @{ $attr{labels} },
              ( ucfirst $key ) . '-' . ucfirst $props{$key};
        }
    }
    return \%attr;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
