package App::SD::CLI::Command::Help::Aliases;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Command Aliases');
    my ${cmd}= $self->_get_cmd_name;

print <<EOF

You can create custom command aliases in your local configuration file.
The format is as follows:

    alias command to type = command to translate it to

As an example, you could create an alias to show all tickets assigned
to you with the alias 'mine':

    alias mine = ticket list -- owner=you\@domain.com status !~closed|rejected

SD also provides a command for managing aliases: '${cmd}aliases'. If
given no arguments, the aliases command will present you with an editor
window in which aliases can be modified. Aliases will be saved to your
local configuration file when editing is done.

The following arguments are supported:

    --show (or -s)
      Don't present an editor window, just print the current aliases
      to STDOUT.

    --add (or -a) 'command to type = command to translate to'
      Add a new alias from the command line.

    --delete (or -d) 'command to type'
      Delete an existing alias from the command line.

For more information on local configuration files, see '${cmd}help config'.

EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

