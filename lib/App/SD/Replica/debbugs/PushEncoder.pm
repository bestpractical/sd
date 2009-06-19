package App::SD::Replica::debbugs::PushEncoder;
use Any::Moose;

use Params::Validate;

has sync_source => 
    ( isa => 'App::SD::Replica::debbugs',
      is => 'rw');

=head2 integrate_change L<Prophet::Change>, L<Prophet::ChangeSet>

Should be able to leave as-is, theoretically.

=cut

sub integrate_change {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );
    my $id;
    eval {
        if (    $change->record_type eq 'ticket'
            and $change->change_type eq 'add_file'
    )
        {
            $id = $self->integrate_ticket_create( $change, $changeset );
            $self->sync_source->record_remote_id_for_pushed_record(
                uuid      => $change->record_uuid,
                remote_id => $id
            );

        } elsif ( $change->record_type eq 'attachment'
            and $change->change_type eq 'add_file'

        ) {
            $id = $self->integrate_attachment( $change, $changeset );
        } elsif ( $change->record_type eq 'comment'
            and $change->change_type eq 'add_file'
        ) {
            $id = $self->integrate_comment( $change, $changeset );
        } elsif ( $change->record_type eq 'ticket' ) {
            $id = $self->integrate_ticket_update( $change, $changeset );

        } else {
            return undef;
        }

        $self->sync_source->record_pushed_transactions(
            ticket    => $id,
            changeset => $changeset
        );

    };
    warn $@ if $@;
    return $id;
}

=head2 integrate_ticket_create L<Prophet::Change>, L<Prophet::ChangeSet>

=cut

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # ...

    # returns the id of the new ticket
    # XXX is this uuid or what?
}

=head2 integrate_comment L<Prophet::Change>, L<Prophet::ChangeSet>

=cut

sub integrate_comment {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # ...

    # returns the remote id of the ticket for this change
}

=head2 integrate_attachment L<Prophet::Change>, L<Prophet::ChangeSet>

=cut

sub integrate_attachment {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # ...

    # returns the remote id of the ticket for this change
}

=head2 integrate_ticket_update L<Prophet::Change>, L<Prophet::ChangeSet>

=cut

sub integrate_ticket_update {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
