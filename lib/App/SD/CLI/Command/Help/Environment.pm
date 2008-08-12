package App::SD::CLI::Command::Help::Environment;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Environment variables');

print <<EOF
  export SD_REPO=/path/to/sd/replica
    Specify where the ticket database SD is using should reside
EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

