package App::SD::CLI::Command::Help::History;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Viewing Database History');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF
You can view a history of all changes to the database using the 'log'
command. It can be run in the following ways:

    ${cmd}log
      Shows the last 20 changes.

    ${cmd}log --all
    ${cmd}log -a
      Shows the entire history from start to end.

    ${cmd}log <since>..<until>
      Shows the range of history starting at <since> and ending at
      <until>. Ranges can be specified using either sequence numbers
      or an offset from the most recent change, designated by
      LATEST~offset.

Examples:

    ${cmd}log 0..5
      Shows changes 0 through 5.

    ${cmd}log LATEST
      Shows the most recent change.

    ${cmd}log LATEST~4
      Shows changes from 4 before the most recent change up to the most
      recent change.

    ${cmd}log 2..LATEST~5
      Shows the second change up through 5 before the latest.

    ${cmd}log LATEST~10..LATEST~5
      Shows changes from 10 before the latest to 5 before the latest.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

