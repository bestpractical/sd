package App::SD::CLI::Command::Help::Environment;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Environment variables');

print <<EOF

  export PROPHET_DEVEL=1
    Turn on various development mode checks, warnings and autoreloading
    of modules

  export PROPHET_USER=name
    Use 'name' as the creator of changesets

  export EMAIL=jesse\@example.com
    Use jesse\@example.com as the default email address for reporting 
    issues

  export PROPHET_REPLICA_TYPE=prophet
    Use the prophet native replica type. In the future other backend
    replica types may be available

  export SD_REPO=/path/to/sd/replica
    Specify where the ticket database SD is using should reside

  export SD_CONFIG=/path/to/sd/config/file
    Specify where the configuration file SD is using should reside


  export PROPHET_HISTFILE=~/.sd-history
    Specify where the interactive shell should store its history

  export PROPHET_HISTLENGTH=100
    Specify how much history the interactive shell should store



EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

