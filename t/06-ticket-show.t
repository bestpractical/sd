#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 6;
use App::SD::Test;
use File::Temp qw/tempdir/;
use Path::Class;
use Term::ANSIColor;

no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}

run_script( 'sd', [ 'init']);

my $replica_uuid = replica_uuid;

# create from sd
my ($ticket_id, $ticket_uuid) = create_ticket_ok( '--summary', 'YATTA');

sub check_output_with_history {
    my @extra_args = @_;

    run_output_matches( 'sd', [ 'ticket', 'show', $ticket_id, @extra_args ],
        [
            '',
            '= METADATA',
            '',
            "id:               $ticket_id ($ticket_uuid)",
            'summary:          YATTA',
            'status:           ' . colored('new', 'red'),
            'milestone:        alpha',
            'component:        core',
            qr/^created:\s+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/,
            qr/^creator:\s+$ENV{USER}$/,
            qr/reporter:\s+$ENV{EMAIL}$/,
            qr/original_replica:\s+$replica_uuid$/,
            '',
            '= HISTORY',
            '',
            qr/^ $ENV{USER} at \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s+\(\d+\@$replica_uuid\)$/,
            "  + \"original_replica\" set to \"$replica_uuid\"",
            "  + \"creator\" set to \"$ENV{USER}\"",
            '  + "status" set to "new"',
            "  + \"reporter\" set to \"$ENV{EMAIL}\"",
            qr/^  \+ "created" set to "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"$/,
            '  + "component" set to "core"',
            '  + "summary" set to "YATTA"',
            '  + "milestone" set to "alpha"',
            '',
        ]
    );
}


sub check_output_without_history {
    my @extra_args = @_;

    run_output_matches( 'sd', [ 'ticket', 'show', $ticket_id, @_],
        [
            '',
            '= METADATA',
            '',
            "id:               $ticket_id ($ticket_uuid)",
            'summary:          YATTA',
            'status:           ' . colored('new', 'red'),
            'milestone:        alpha',
            'component:        core',
            qr/^created:\s+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/,
            qr/^creator:\s+$ENV{USER}$/,
            qr/reporter:\s+$ENV{EMAIL}$/,
            qr/original_replica:\s+$replica_uuid$/,
        ]
    );
}

diag('default (shows history)');

check_output_with_history();

diag("passing --skip history (doesn't show history)");

check_output_without_history('--skip-history');

my $config_filename = $ENV{'SD_REPO'} . '/sdrc';
App::SD::Test->write_to_file($config_filename,
    "disable_ticket_show_history_by_default = 1\n");
$ENV{'SD_CONFIG'} = $config_filename;

diag("config option disable_ticket_show_history_by_default set");
diag("(shouldn't show history)");

check_output_without_history();

diag("config option disable_ticket_show_history_by_default set");
diag("and --skip-history passed (shouldn't show history)");

check_output_without_history('--skip-history');

# config option set and --show-history passed (should show history)
diag('config option disable_ticket_show_history_by_default set');
diag('and --show-history passed (should show history)');

check_output_with_history('--show-history');
