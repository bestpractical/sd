package App::SD::CLI::Command::Ticket::Resolve;
use Moose;
extends 'Prophet::CLI::Command::Update';

before run => sub {
    my $self = shift;
    $self->set_prop(status => 'closed');
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

