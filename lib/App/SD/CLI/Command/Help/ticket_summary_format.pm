package App::SD::CLI::Command::Help::ticket_summary_format;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('The ticket.summary-format configuration option');

print <<EOF
The ticket.summary-format configuration directive consists of any number
of comma-separated pairs, with each pair separated from the next by a vertical
bar (|). Any amount of whitespace may appear before or after the | and will not
affect the summary format.

Here is an example:

    [ticket]
        summary-format = %5.5s },\$luid | %8.8s,status | %-52.52s,summary

Let's deconstruct this example. It consists of three pairs. The first pair is
'%5.5s },\$luid'. The first item of the pair should look somewhat familiar to
anyone who's programmed in Perl or C before. It consists of a format string,
like that used in Perl's and C's printf function, and can be prefixed or
followed by any other characters (' }' in this case).

The second item is the property to be formatted. It can be any ticket property,
but if you want the local uid (luid) or the universal uid (uuid), it must be
prefixed with the \$ character (see the first pair in the example).

When printing the summary format for the ticket, the value of the given
property for that ticket will be subbed into the format string (e.g. '%s') and
any non-format characters in the format field will be printed as-is. If no
format field is supplied with a given pair, '%s' is assumed.

For more help on format strings, see
http://perldoc.perl.org/functions/sprintf.html.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

