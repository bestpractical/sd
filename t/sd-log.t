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
        = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag $ENV{'PROPHET_REPO'};
}

run_script( 'sd', [ 'init']);

my $replica_uuid = replica_uuid;

# create a ticket
my ($log_id, $log_uuid) = create_ticket_ok( '--', 'summary', 'logs rock!');
# check the log

run_output_matches( 'sd', [ 'log', '--count', '1' ],
    [
        qr/^\d{4}-\d{2}-\d{2}.+ - $ENV{USER} @ $replica_uuid$/,
        qr/^ # Ticket \d+ \(logs rock!\)$/,
        '  + "original_replica" set to "'.$replica_uuid.'"',
        '  + "creator" set to "'.$ENV{USER}.'"',
        '  + "status" set to "new"',
        '  + "reporter" set to "'.$ENV{EMAIL}.'"',
        qr/^  \+ "created" set to "\d{4}-\d{2}-\d{2}.+"$/,
        '  + "component" set to "core"',
        '  + "summary" set to "logs rock!"',
        '  + "milestone" set to "alpha"',
        '',
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
run_output_matches( 'sd', [ 'log', '--count', '1' ],
    [
        qr/^\d{4}-\d{2}-\d{2}.+ - $ENV{USER} @ $replica_uuid$/,
        qr/^ # Ticket \d+ \(logs rock!\)$/,
        '  > "reporter" changed from "'.$ENV{EMAIL}.'" to "foo@bar.com".',
        '',
    ], [], "log output is correct",
);

# delete a prop XXX delete is currently implemented only as setting a prop
# to '', so it will never actually show up in the log as deleted
# check the log

# check the log specifying --count --last
# args for the log command: --last, --count
# count does: specifies the number of log entries to output
# last does: specifies the last entry that you want shown (newest entry is default)

