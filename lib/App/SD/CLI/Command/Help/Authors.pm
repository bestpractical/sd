package App::SD::CLI::Command::Help::Authors;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    my ${cmd}= $self->cli->get_script_name;
    $self->print_header("Authors");

print <<EOF

(in alphabetical order)

Chia-liang Kao <clkao\@clkao.org>
Shawn Moore <sartak\@sartak.org>
Christine Spang <spang\@mit.edu>
Jesse Vincent <jesse\@fsck.com>
Casey West <casey\@geeknest.com>
Simon Wistow <simon\@thegestalt.org>
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

