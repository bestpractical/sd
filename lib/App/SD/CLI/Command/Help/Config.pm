package App::SD::CLI::Command::Help::Config;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Configuration Options');
    my $cmd = $self->_get_cmd_name;

print <<EOF
SD supports both a user-wide configuration file (\$HOME/.sdrc and
per-database configuration file (/path/to/repo/sdrc). If both configuration
files are present, the database-specific config file will be used.

Currently, the following configuration variables are available:

    email_address = foo\@bar.com
      Specifies an email address to use as the default for tickets'
      reporter field. (Overrides the EMAIL environmental variable if
      that is also set.)

    summary_format_ticket = %4s },\$luid | %-11.11s,status | %-60.60s,summary
      Specifies how to format ticket summaries (when listing tickets, e.g.).
      (See also: help summary_format_ticket.)

    default_sort_ticket_list = status
      Bug property to determine order of display when listing tickets. (Can
      be any property; will be compared lexically.)

    default_group_ticket_list = milestone
      Bug property to group tickets by when displaying lists. (Can be any
      property.)

    disable_ticket_show_history_by_default = 1
      Don't display ticket history when running '$cmd ticket show'. Can
      be overridden by passing the '--show-history' arg to the
      command.

For information on environmental variables that can affect SD, see
'$cmd help environment'.
EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

