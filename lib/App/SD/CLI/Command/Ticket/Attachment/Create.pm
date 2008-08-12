package App::SD::CLI::Command::Ticket::Attachment::Create;
use Moose;
extends 'App::SD::CLI::Command::Attachment::Create';
# override args to feed in that ticket's uuid as an argument to the comment

before run => sub {
    my $self = shift;
    $self->require_uuid;

    $self->set_prop(ticket => $self->cli->uuid);
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

