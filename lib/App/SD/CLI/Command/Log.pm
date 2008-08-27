package App::SD::CLI::Command::Log;
use Moose;
extends 'Prophet::CLI::Command::Log';

sub handle_changeset {
    my $self      = shift;
    my $changeset = shift;
    print $changeset->as_string(
        change_filter => sub {
            my $change = shift;
            return undef if $change->record_type eq '_merge_tickets';
            return 1;
        },
        change_header => sub {
            my $change = shift;
            $self->change_header($change)."\n";
        },
        header_callback => sub {
            my $c = shift;
            sprintf "Change %d by %s at %s\n",
                $c->sequence_no,
                ( $c->creator || '(unknown)' ),
                $c->created,
                ;
            }

    );

}


sub change_header {
    my $self   = shift;
    my $change = shift;

    if (my $sub = $self->can("change_header_".$change->record_type)) {
        return $sub->($self, $change);
    }

    else {
    return
          " # "
        . ucfirst($change->record_type) . " "
        . $self->app_handle->handle->find_or_create_luid(
        uuid => $change->record_uuid )
        . " ("
        . $change->record_uuid . ")";
    }
}

sub change_header_ticket {
    my $self = shift;
    my $change = shift;
    require App::SD::Model::Ticket;
    my $t = App::SD::Model::Ticket->new( handle => $self->handle, type => App::SD::Model::Ticket->type);
    $t->load(uuid => $change->record_uuid);
    return " # Ticket "
        . $self->app_handle->handle->find_or_create_luid(
        uuid => $change->record_uuid )
        . " (".$t->prop('summary').")"
}

__PACKAGE__->meta->make_immutable;
no Moose;
