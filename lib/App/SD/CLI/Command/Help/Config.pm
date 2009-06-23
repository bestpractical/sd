package App::SD::CLI::Command::Help::Config;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Configuration Options');
    my ${cmd}= $self->_get_cmd_name;

print <<EOF
SD supports a layered configuration system with three configuration
files: a global file (/etc/sdrc), a user-wide configuration file
(\$HOME/.sdrc) and per-replica configuration file (/path/to/replica/config).
Configuration variables in more local configuration files override
those in more global ones.

You can use the '${cmd}config' command to view what configuration files
SD has loaded and all loaded configuration variables, as they apply
to the current replica.

The configuration file format is similar to that of the VCS 'Git'. See
http://www.kernel.org/pub/software/scm/git/docs/git-config.html for
specifics. The biggest thing you need to know is that the config file
contains key/value variables, contained in sections. In the help
documents, we'll refer to variables in the manner:
"section.subsection.variable-name". In a configuration file, this
would look like:

    [section "subsection]
        variable-name = value

Currently, the following configuration variables are available (sorted
by configuration file section):

    ticket.summary-format = %4s },\$luid | %-11.11s,status | %-60.60s,summary
      Specifies how to format ticket summaries (when listing tickets, e.g.).
      (See also: help ticket-summary-format.)

    ticket.common-props = id,summary,status,owner,created,original_replica
      A comma-separated list of ticket properties that are most-often
      used. These properties will be shown by default in the 'ticket
      show' command and presented for editing when interactively
      creating or updating tickets. (Overrides the database-wide
      setting of the same name.)

    ticket.search.default-sort = status
      Bug property to determine order of display when searching/listing
      tickets. (Can be any property; will be compared lexically.)

    ticket.search.default-group = milestone
      Bug property to group tickets by when displaying searches/lists. (Can be
      any property.)

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

