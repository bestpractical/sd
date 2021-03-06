#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 4;
use App::SD::Test;
use Prophet::Util;
no warnings 'once';

# test the 'log' command

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag $ENV{'PROPHET_REPO'};
}

run_script( 'sd', [ 'init', '--non-interactive']);

my $replica_uuid = replica_uuid;

# create a ticket
my ($log_id, $log_uuid) = create_ticket_ok( '--', 'summary', 'logs rock!');
# check the log

run_output_matches( 'sd', [ 'log', 'LATEST' ],
    [
        qr/^$/,
        qr/^=+$/,
        qr/^\d{4}-\d{2}-\d{2}.+ - $ENV{PROPHET_EMAIL} : \d+\@\Q$ENV{PROPHET_REPO}\E$/,
        qr/^Ticket \d+ \(logs rock!\)$/,
        qr/^-+$/,
        qr/created: set to \d{4}-\d{2}-\d{2}.+/,
        qr/original_replica: set to $replica_uuid/,
        qr/creator: set to $ENV{PROPHET_EMAIL}/,
        qr/component: set to core/,
        qr/summary: set to logs rock!/,
        qr/status: set to new/,
        qr/milestone: set to alpha/,
        qr/reporter: set to $ENV{PROPHET_EMAIL}/,
        qr/^$/,
    ], [], "log output is correct",
);
# change a prop
run_output_matches( 'sd', [ 'ticket',  
    'update', '--uuid', $log_uuid, '--', '--reporter', 'foo@bar.com',
    ],
    [qr/Ticket $log_id \($log_uuid\) updated/], #stdout
   [], # stderr
   "deleting a prop went ok",
);
# check the log
run_output_matches( 'sd', [ 'log', 'LATEST' ],
    [
        '',
        qr/^=+/,
        qr/^\d{4}-\d{2}-\d{2}.+ - $ENV{PROPHET_EMAIL} : \d+\@\Q$ENV{PROPHET_REPO}\E$/,
        qr/^Ticket \d+ \(logs rock!\)$/,
        qr/^-+/,
        qr/reporter: changed from $ENV{PROPHET_EMAIL} to foo\@bar.com/,
        '',
    ], [], "log output is correct",
);

# delete a prop XXX delete is currently implemented only as setting a prop
# to '', so it will never actually show up in the log as deleted
# check the log

# we don't need to test the range-specifying heavily since Prophet already
# does this
