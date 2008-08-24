package App::SD::CLI::Command::Ticket::Comment::Create;
use Moose;

extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::TicketComment';
with 'App::SD::CLI::Command';

# override args to feed in that ticket's uuid as an argument to the comment
before run => sub {
    my $self = shift;
    $self->require_uuid;

    my $content = $self->get_content(type => 'comment', default_edit => 1);

    die "Aborted.\n"
        if length($content) == 0;

    $self->set_prop(ticket => $self->uuid);
    $self->set_prop(content => $content);
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

