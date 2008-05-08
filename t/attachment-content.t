#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 6;

use File::Temp qw/tempdir/;
use Path::Class;

my $dir = tempdir(CLEANUP => 1);

my $file=  file($dir => 'paper_order.doc');

open (my $fh, ">" , $file) || die "Could not create $file: $!";
print $fh "5 tonnes of hard white" || die "Could not write to file $file $!";
close $fh || die $!;

no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    warn "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}
# create from sd and push
my $yatta_uuid;
run_output_matches( 'sd', [ 'ticket',
    'create', '--summary', 'YATTA', '--status', 'new' ],
    [qr/Created ticket (.*)(?{ $yatta_uuid = $1 })/]
);

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ sort "$yatta_uuid YATTA new"]
);

my $attachment_uuid;
run_output_matches('sd', [qw/ticket attachment create --uuid/, $yatta_uuid, '--file', $file], [qr/Created attachment (.*?)(?{ $attachment_uuid = $1})$/], [], "Added a attachment");
ok($attachment_uuid);

run_output_matches('sd', [qw/ticket attachments --uuid/, $yatta_uuid], [qr/^attachment id: $attachment_uuid/, 
    'name: paper_order.doc', 
    'content_type: text/plain' ], [], "Found the attachment, but doesn't show the content");


run_output_matches('sd', [qw/attachment content --uuid/, $attachment_uuid], ['5 tonnes of hard white'],[], "We got the content");

