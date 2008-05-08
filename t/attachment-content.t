#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 10;

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


diag("Add a binary attachment");

my $image_attach;
my $image_file = 't/data/bplogo.gif';

run_output_matches('sd', [qw/ticket attachment create --uuid/, $yatta_uuid, '--file', $image_file], [qr/Created attachment (.*?)(?{ $image_attach = $1})$/], [], "Added a attachment");

my $image_data = file($image_file)->slurp;

my ($ret, $stdout, $stderr) = run_script('sd', [qw/attachment content --uuid/, $image_attach]);
ok($ret, "Ran the script ok");
is($stdout, $image_data, "We roundtripped some binary");
is($stderr, '');

