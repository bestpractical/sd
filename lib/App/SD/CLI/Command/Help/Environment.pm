package App::SD::CLI::Command::Help::Environment;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Environment variables');
    my ${cmd}= $self->_get_cmd_name;

print <<EOF

The following environmental variables can be set to affect SD's
configuration. Example syntax is for bash-like shells.

    export PROPHET_DEVEL=1
      Turn on various development mode checks, warnings and autoreloading
      of modules.

    export PROPHET_USER=name
      Use 'name' as the creator of changesets.

    export EMAIL=jesse\@example.com
      Use jesse\@example.com as the default email address for reporting 
      tickets.

    export PROPHET_REPLICA_TYPE=prophet
      Use the prophet native replica type. Other backend replica
      types are: sqlite.

    export SD_REPO=/path/to/sd/replica
      Specify where the ticket database SD is using should reside.

    export SD_CONFIG=/path/to/sd/config/file
      Specify where the configuration file SD is using should reside.

    export PROPHET_HISTFILE=~/.sd-history
      Specify where the interactive shell should store its history.

    export PROPHET_HISTLENGTH=100
      Specify how much history the interactive shell should store.

For information on SD database configuration files, see '${cmd}help config'.
EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

