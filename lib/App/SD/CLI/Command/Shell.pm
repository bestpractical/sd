package App::SD::CLI::Command::Shell;
use Moose;
extends 'Prophet::CLI::Command::Shell';

sub preamble {
    my $self = shift;
    return join "\n",
        "SD for ".$self->app_handle->setting( label => 'project_name' )->get()->[0]." ($App::SD::VERSION; Prophet $Prophet::VERSION)",
        'Type "help", "about", or "copying" for more information.',
}

1;

