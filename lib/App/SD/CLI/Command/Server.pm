package App::SD::CLI::Command::Server;
use Any::Moose;
extends 'Prophet::CLI::Command::Server';

sub run {
    my $self = shift;
    $self->server->read_only(1) unless ($self->has_arg('writable'));

    $self->SUPER::run();
}

1;
