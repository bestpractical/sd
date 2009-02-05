package App::SD::CLI::Command::Help::Settings;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Database Settings');
    my ${cmd}= $self->_get_cmd_name;

print <<EOF
The 'settings' command allows you to modify configuration variables
that propagate with the current database, known as settings.

If given no arguments, the settings command will present you with
an editor window in which settings can be modified. Setting values
must be valid JSON data structures.

The following arguments are supported:

    --show (or -s)
      Don't present an editor window, just print the current
      settings to STDOUT.

    --set -- common_ticket_props '["id", "summary", "original_replica"]'
      Update the setting common_ticket_props to the given value.

Settings are not the same as local configuration variables. For
more information on local configuration, see '${cmd}help config'.

EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

