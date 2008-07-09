package App::SD::CLI::Command::Ticket::Attachment::Search;
use Moose;
extends 'Prophet::CLI::Command::Search';
with 'Prophet::CLI::RecordCommand';
with 'App::SD::CLI::Model::Attachment';
# override args to feed in that ticket's uuid as an argument to the comment


sub type {'attachment'}
sub get_search_callback {
    my $self = shift;
    return sub {
        shift->prop('ticket') eq $self->uuid ? 1 : 0;
        }

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

