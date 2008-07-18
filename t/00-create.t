#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 2;
use App::SD::Test;
use File::Temp qw/tempdir/;
use Path::Class;


no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    warn "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}
# create from sd and push
my ($yatta_id, $yatta_uuid) = create_ticket_ok( '--summary', 'YATTA');

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA new/]
   
);

