package App::SD::CLI::Command::Shell;
use Moose;
extends 'Prophet::CLI::Command::Shell';

sub preamble {
    return join "\n",
        "SD ($App::SD::VERSION; Prophet $Prophet::VERSION)",
        'Type "help", "about", or "copying" for more information.',
}

1;

