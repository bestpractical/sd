package App::SD::CLI::Command::Server;
use Any::Moose;
extends 'Prophet::CLI::Command::Server';

sub run {
    my $self = shift;
    my $server = $self->setup_server();
    $server->read_only(1) unless ($self->has_arg('writable'));
    Prophet::CLI->end_pager();

    $server->run;
}   

1;
