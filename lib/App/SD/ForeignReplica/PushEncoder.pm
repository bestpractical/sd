package App::SD::ForeignReplica::PushEncoder;
use Any::Moose;
use Params::Validate;


sub integrate_change {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );
    my ($id, $record);

    # if the original_sequence_no of this changeset is <= 
    # the last changeset our sync source for the original_sequence_no, we can skip it.
    # XXX TODO - this logic should be at the changeset level, not the cahnge level, as it applies to all
    # changes in the changeset
    

    my $before_integration = time();


    eval {
        if (    $change->record_type eq 'ticket'
            and $change->change_type eq 'add_file' ) {
            $id = $self->integrate_ticket_create( $change, $changeset );
            $self->sync_source->record_remote_id_for_pushed_record(
                uuid      => $change->record_uuid,
                remote_id => $id);
        }
        elsif ( $change->record_type eq 'attachment'
            and $change->change_type eq 'add_file') {
            $id = $self->integrate_attachment( $change, $changeset );
        }
        elsif ( $change->record_type eq 'comment'
            and $change->change_type eq 'add_file' ) {
            $id = $self->integrate_comment( $change, $changeset );
        }
        elsif ( $change->record_type eq 'ticket' ) {
            $id = $self->integrate_ticket_update( $change, $changeset );
        }
        else {
            $self->sync_source->log('I have no idea what I am doing for '.$change->record_uuid);
            return undef;
        }

        $self->sync_source->record_pushed_transactions(
            start_time => $before_integration,
            ticket    => $id,
            changeset => $changeset);
    };

    if (my $err = $@) {
        $self->sync_source->log("Push error: ".$err);
    }

    $self->after_integrate_change();
    return $id;
}

sub after_integrate_change {}

no Any::Moose;
__PACKAGE__->meta->make_immutable;

1;
