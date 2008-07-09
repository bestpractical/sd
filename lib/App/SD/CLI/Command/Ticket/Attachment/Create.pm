package App::SD::CLI::Command::Ticket::Attachment::Create;
use Moose;
extends 'App::SD::CLI::Command::Attachment::Create';
# override args to feed in that ticket's uuid as an argument to the comment

override run => sub  {
    my $self = shift;
    $self->args->{'ticket'} = $self->cli->uuid;
    super(@_);
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

