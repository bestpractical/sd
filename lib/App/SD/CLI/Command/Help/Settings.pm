package App::SD::CLI::Command::Help::Settings;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Database Settings');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF
The 'settings' command allows you to modify configuration variables
that propagate with the current database, known as settings.

If given no arguments, the settings command will print the current
settings.

The following arguments are supported:

    show
      Don't present an editor window, just print the current
      settings to STDOUT.

    edit
      Present an editor window containing all the current settings
      for interactive editing.

    set -- common_ticket_props '["id", "summary", "original_replica"]'
      Update the setting common_ticket_props to the given value.
      Any setting, including multiple settings, may be set this way.

Setting values must be valid JSON.

Settings are not the same as local configuration variables. For
more information on local configuration, see '${cmd}help config'.

EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

