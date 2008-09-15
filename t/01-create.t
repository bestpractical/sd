#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 3;
use App::SD::Test;
use File::Temp qw/tempdir/;
use Path::Class;


no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}

# create from sd and push
my ($yatta_id, $yatta_uuid) = create_ticket_ok( '--summary', 'YATTA');

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA new/]
   
);

run_output_matches( 'sd', [ 'ticket', 'basics', '--batch', '--id', $yatta_id ],
    [
        "id: $yatta_id ($yatta_uuid)",
        'summary: YATTA',
        'status: new',
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        qr/^creator: /,
        "original_replica: " . replica_uuid,
    ]
);

