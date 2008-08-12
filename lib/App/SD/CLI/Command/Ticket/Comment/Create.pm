package App::SD::CLI::Command::Ticket::Comment::Create;
use Moose;

extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::TicketComment';
with 'App::SD::CLI::Command';

# override args to feed in that ticket's uuid as an argument to the comment
before run => sub {
    my $self = shift;
    $self->set_prop(ticket => $self->cli->uuid);
    $self->set_prop(content => $self->get_content(type => 'comment', default_edit => 1));
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

