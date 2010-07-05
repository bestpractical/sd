package App::SD::CLI::Command::Log;
use Any::Moose;
extends 'Prophet::CLI::Command::Log';

use App::SD::CLI::Command::Ticket::Show;

sub handle_changeset {
    my $self      = shift;
    my $changeset = shift;
    print $changeset->as_string(
        skip_empty => 1,
        change_filter => sub {
            my $change = shift;
            return undef if $change->record_type eq '_merge_tickets';
            if ($change->record_type eq 'comment') {
            }
            return 1;
        },
        change_formatter => sub {
            App::SD::CLI->format_change(@_);
            },

        change_header => sub {
            my $change = shift;
            $self->change_header($change)."\n".("-"x80)."\n";
        },
        header_callback => sub {
            my $c = shift;
            print "\n".("="x80) .  "\n";
            sprintf "%s - %s : %s@%s\n",
                $c->created,
                ( $c->creator || '(unknown)' ),
                $c->original_sequence_no,
                $self->app_handle->display_name_for_replica($c->original_source_uuid)
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
        return $self->change_header_generic($change);
    }
}
sub change_header_generic {
    my $self = shift;
    my $change = shift;
    return
        ucfirst($change->record_type) . " "
        . $self->app_handle->handle->find_or_create_luid(
        uuid => $change->record_uuid )
        . " ("
        . $change->record_uuid . ")";
}


sub change_header_comment {
    my $self = shift;
    my $change = shift;
    require App::SD::Model::Comment;
    my $c = App::SD::Model::Comment->new( app_handle => $self->app_handle );
    $c->load(uuid => $change->record_uuid);
    if ($c->prop('ticket')) {
    my $t = $c->ticket;
    return "Comment on ticket " . $t->luid . " (".$t->prop('summary').")"
    } else {
        return "Comment on unknown ticket";
    }
}

sub change_header_ticket {
    my $self = shift;
    my $change = shift;
    require App::SD::Model::Ticket;
    my $t = App::SD::Model::Ticket->new( app_handle => $self->app_handle );
    $t->load(uuid => $change->record_uuid);
    unless ($t->uuid) {
        return $self->change_header_generic($change);
    }
    return "Ticket "
        . $self->app_handle->handle->find_or_create_luid(
        uuid => $change->record_uuid )
        . " (".($t->prop('summary')||'').")"
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
