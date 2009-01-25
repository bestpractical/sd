package App::SD::CLI::Command::Shell;
use Moose;
extends 'Prophet::CLI::Command::Shell';

has project_name => (
    isa => 'Str',
    is => 'rw',
    default => sub { shift->app_handle->setting( label => 'project_name' )->get()->[0]; }
    );

sub preamble {
    my $self = shift;
    return join "\n",
        "SD for ".$self->project_name." ($App::SD::VERSION; Prophet $Prophet::VERSION)",
        'Type "help", "about", or "copying" for more information.',
}

sub prompt {
    my $self = shift;

    return $self->project_name.">";
}


1;

