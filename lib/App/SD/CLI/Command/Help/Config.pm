package App::SD::CLI::Command::Help::Config;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Configuration Options');

print <<EOF
  SD supports both a user-wide configuration (\$HOME/.sdrc and per-database
  configuration (/path/to/repo/sdrc). If both configuration files are present,
  the database-specific config file will be used.

  Currently, the following configuration variables are available:

  reporter_email = foo\@bar.com
    Specifies an email address to use as the default for tickets'
    reported_by field.

  summary_format_ticket = %4s },\$luid | %-11.11s,status | %-60.60s,summary
    Specifies how to format ticket summaries (when listing tickets, e.g.).
EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

