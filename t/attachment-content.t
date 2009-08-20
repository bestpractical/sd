#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 10;
use App::SD::Test;
use File::Temp qw/tempdir/;

my $dir = tempdir(CLEANUP => 1);

my $file= File::Spec->catfile($dir, 'paper_order.doc');

open (my $fh, ">" , $file) || die "Could not create $file: $!";
print $fh "5 tonnes of hard white" || die "Could not write to file $file $!";
close $fh || die $!;

no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}
run_script( 'sd', [ 'init', '--non-interactive']);


# create from sd and push
my ($yatta_id, $yatta_uuid) = create_ticket_ok( '--summary', 'YATTA', '--status', 'new' );

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA new/]
   
);

my $attachment_uuid;
my $attachment_id;
run_output_matches(
    'sd',
    [ qw/ticket attachment create --uuid/, $yatta_uuid, '--file', $file ],
    [   qr/Created attachment (\d+)(?{$attachment_id = $1}) \((.*?)(?{ $attachment_uuid = $2})\)$/
    ],
    [],
    "Added a attachment"
);
ok($attachment_uuid);
run_output_matches(
    'sd',
    [ qw/ticket attachment list --uuid/, $yatta_uuid ],
    [ $attachment_id . " paper_order.doc text/plain" ],
    ,
    [],
    "Found the attachment, but doesn't show the content"
);

run_output_matches(
    'sd',
    [ qw/attachment content --uuid/, $attachment_uuid ],
    ['5 tonnes of hard white'],
    [], "We got the content"
);


diag("Add a binary attachment");

my $image_attach;
my $image_file = 't/data/bplogo.gif';

run_output_matches('sd', [qw/ticket attachment create --uuid/, $yatta_uuid, '--file', $image_file], [qr/Created attachment (\d+)(?{ $image_attach = $1})/], [], "Added a attachment");

my $image_data = Prophet::Util->slurp( $image_file );
my ($ret, $stdout, $stderr) = run_script('sd', [qw/attachment content --id/, $image_attach]);
ok($ret, "Ran the script ok");
is($stdout, $image_data, "We roundtripped some binary");
is($stderr, '');

