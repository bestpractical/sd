package App::SD::CLI::Command::Shell;
use Any::Moose;
extends 'Prophet::CLI::Command::Shell';

has project_name => (
    isa     => 'Str',
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        if ( $self->app_handle->handle->replica_exists ) {
            return $self->app_handle->setting( label => 'project_name' )->get()->[0];
        } else {
            return 'No database found';
        }
    }
);

sub preamble {
    my $self = shift;
    my @out  = (
        "SD for " . $self->project_name . " ($App::SD::VERSION; Prophet $Prophet::VERSION)",
        'Type "help", "about", or "copying" for more information.'
    );

    if ( !$self->app_handle->handle->replica_exists ) {
        push @out, '', "No SD database was found at " . $self->app_handle->handle->url(),
            'Type "help init" and "help environment" for tips on how to sort that out.';
    }

    return join( "\n", @out );

}

sub prompt {
    my $self = shift;

    return $self->project_name . "> ";
}

1;

