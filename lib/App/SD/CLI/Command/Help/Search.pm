package App::SD::CLI::Command::Help::Search;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Searching for and displaying tickets');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF

    ${cmd}ticket search
      List all tickets with a status that does not match 'closed'.
      Note that 'list' is an alias for 'search'.

    ${cmd}ticket search --regex abc
      List all tickets with content matching 'abc'. Regular
      expressions are Perl regexes.

    ${cmd}ticket search -- status!=closed summary =~ http 
      List all tickets with a status that does match closed
      and a summary matching 'http'.

    ${cmd}ticket search --group owner
    ${cmd}ticket search -g owner
       List all tickets with a status that does not match 'closed', 
       grouped by owner.

    ${cmd}ticket search --sort due
    ${cmd}ticket search -s due
       List all tickets with a status that does not match 'closed',
       sorted by due date.

    ${cmd}ticket basics 1234
      Show basic information (metadata only) for the ticket with local id 1234.

    ${cmd}ticket show 1234
      Show basic information, comments, and history for the ticket with local
      id 1234.  ('details' is an alias for 'show')

    ${cmd}ticket show 1234 --all-props
    ${cmd}ticket show 1234 -a
      Show all properties of the given ticket, even if they aren't in
      the database setting common_ticket_props (or local configuration
      variable 'common_ticket_props' if it exists).

    ${cmd}ticket show 1234 --skip-history
    ${cmd}ticket show 1234 -s
      Show only metadata and comments for the ticket 1234 (but not
      history).

    ${cmd}ticket show 1234 --with-history
    ${cmd}ticket show 1234 -h
      Override the disable_ticket_show_history_by_default config option
      if it is set for this database. (See '${cmd}help config' for
      more info.)

    ${cmd}ticket history 1234
      Show history for the ticket with local id 1234.

    ${cmd}ticket delete 1234
      Delete ticket with local id 1234.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

