package App::SD::CLI::Command::Version;

use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run { 
    my $self = shift;
    print $self->version ."\n";
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

