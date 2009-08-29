package App::SD::CLI::Command::Help::Config;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Configuration Options');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF
SD supports a layered configuration system with three configuration
files: a global file (/etc/sdrc), a user-wide configuration file
(\$HOME/.sdrc) and a per-replica configuration file (/path/to/replica/config).
Configuration variables in more local configuration files override
those in more global ones.

You can use the '${cmd}config' command to view what configuration files
SD has loaded and all loaded configuration variables, as they apply
to the current replica.

'${cmd}config' can also be used to set configuration variables.

Examples:

    ${cmd}config user.email-address user\@example.com
    ${cmd}config --delete user.email-address
    ${cmd}config user.email-address
      Print the current value of this configuration variable.
    ${cmd}config alias.'this.alias.contains.dots' 'so it must be quoted'
    ${cmd}config edit
    ${cmd}config edit --user
    ${cmd}config edit --global
      Edit the specified config file in an editor.

The configuration file format is similar to that of the VCS 'Git'. See
http://www.kernel.org/pub/software/scm/git/docs/git-config.html for
specifics. The biggest thing you need to know is that the config file
contains key/value variables, contained in sections and subsections.

In the help documents, we'll refer to variables in the manner:
"section-name.subsection-name.variable-name". In a configuration file,
this would look like:

    [section-name "subsection-name"]
        variable-name = value

Here's an example of an actual configuration file, aimed at being
a user-wide config file that affects all bug databases:

    [user]
        email-address = me\@example.com
    [ticket]
        summary-format = %5.5s,\$luid | %8.8s,status | %7.7s,component |%12.12s,owner| %-44.44s,summary
        default-group = milestone
    [alias]
        mine = ticket list -- owner=~me status!~closed|rejected

Currently, the following configuration variables are available (sorted
by configuration file section):

    ticket.summary-format = %4s },\$luid | %-11.11s,status | %-60.60s,summary
      Specifies how to format ticket summaries (when listing tickets, e.g.).
      (See also: '${cmd}help ticket.summary-format'.)

    ticket.common-props = id,summary,status,owner,created,original_replica
      A comma-separated list of ticket properties that are most-often
      used. These properties will be shown by default in the 'ticket
      show' command and presented for editing when interactively
      creating or updating tickets. (Overrides the database-wide
      setting of the same name.)

    ticket.default-sort = status
      Bug property to determine order of display when displaying lists of
      tickets. (Can be any property; will be compared lexically.)

    ticket.default-group = milestone
      Bug property to group tickets by when displaying lists of tickets. (Can
      be any property.)

    ticket.show.disable-history = 1
      Don't display ticket history when running '${cmd}ticket show'. Can
      be overridden by passing the '--with-history' arg to the
      command.

    user.email-address = foo\@bar.com
      Specifies an email address to use as the default for tickets'
      reporter field. (Overrides the EMAIL environmental variable if
      that is also set.)

For information on environmental variables that can affect SD, see
'${cmd}help environment'.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

