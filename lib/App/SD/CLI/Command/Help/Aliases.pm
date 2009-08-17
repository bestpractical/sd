package App::SD::CLI::Command::Help::Aliases;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Command Aliases');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF

You can create custom command aliases in the aliases section of
your local configuration files. The format is as follows:

    [alias]
        command to type = command to translate it to

As an example, you could create an alias to show all tickets assigned
to you with the alias 'mine':

    mine = ticket list -- owner=you\@domain.com status !~closed|rejected

To create aliases that take additional arguments, use the argument
number prefixed with a '\$' to refer to them, like this:

    ts = ticket show \$1

SD also provides a command for managing aliases: '${cmd}aliases'. If
given no arguments, the aliases command will print the active aliases
for the current repository (including all non-overridden user-wide
and global aliases, if any). '${cmd}aliases edit' will present you with an
editor window in which aliases can be modified. Aliases will be saved to your
local configuration file when editing is done.

Examples (in all examples, 'alias' can be used anywhere 'aliases' appears
and vice-versa):

    ${cmd}aliases
    ${cmd}aliases show
      Show currently active aliases.

    ${cmd}aliases edit
      Edit aliases in an editor window.

    ${cmd}alias "command to type" "command to translate to"
      Set the given alias (or change it if it already exists).

    ${cmd}aliases delete "command to type"
      Delete the given alias.

The --user and --global arguments can be used in conjunction with the
set (and edit) commands to change what configuration file to use.
By default, the repository-specific configuration file is used.

For more information on local configuration files, see '${cmd}help config'.

EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

