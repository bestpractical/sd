#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 9;

no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    warn $ENV{'PROPHET_REPO'};
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

my $comment_uuid;
run_output_matches('sd', [qw/ticket comment create --uuid/, $yatta_uuid, '--content', "'This is a test'"], [qr/Created comment (.*?)(?{ $comment_uuid = $1})$/], [], "Added a comment");
ok($comment_uuid);

run_output_matches('sd', [qw/ticket comments --uuid/, $yatta_uuid], [qr/^comment id: $comment_uuid/,'Content:',"'This is a test'"], [], "Found the comment");

run_output_matches('sd', [qw/ticket comment show --uuid/, $comment_uuid], ["id: $comment_uuid", qr/This is a test/, "ticket: $yatta_uuid"], [], "Found the comment");
run_output_matches('sd', [qw/ticket comment update --uuid/, $comment_uuid, qw/--content/, "I hate you" ], [qr/comment $comment_uuid updated/], [], "updated the comment");
run_output_matches('sd', [qw/ticket comment show --uuid/, $comment_uuid], ["id: $comment_uuid", qr/I hate you/, "ticket: $yatta_uuid"], [], "Found the comment new version");

run_output_matches('sd', [qw/ticket comment list --uuid/, $yatta_uuid], [qr/$comment_uuid/], [], "Found the comment when we tried to search for all comments on a ticket by the ticket's uuid");
