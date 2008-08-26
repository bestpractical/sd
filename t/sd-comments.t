#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 8;
use App::SD::Test;
no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag $ENV{'PROPHET_REPO'};
}

# create from sd and push

my ( $yatta_luid, $yatta_uuid )
    = create_ticket_ok( '--summary', 'YATTA', '--status', 'new' );

my ( $comment_id, $comment_uuid )
    = create_ticket_comment_ok( qw/--uuid/, $yatta_uuid, '--content',
    "'This is a test'" );
ok($comment_uuid);

run_output_matches(
    'sd',
    [ qw/ticket comments --uuid/, $yatta_uuid ],
    [ qr/^id: \d+ \($comment_uuid\)/, qr/^created: /, "'This is a test'" ],
    [], "Found the comment"
);

run_output_matches(
    'sd',
    [ qw/ticket comment show --batch --uuid/, $comment_uuid ],
    [   qr/id: (\d+) \($comment_uuid\)/,
        qr/This is a test/,
        qr/created: /,
        qr/creator: /,
        "ticket: $yatta_uuid"
    ],
    [],
    "Found the comment"
);
run_output_matches(
    'sd',
    [   qw/ticket comment update --uuid/, $comment_uuid,
        '--',
        qw/--content/,                    "I hate you"
    ],
    [qr/comment \d+ \($comment_uuid\) updated/],
    [],
    "updated the comment"
);
run_output_matches(
    'sd',
    [ qw/ticket comment show --batch --uuid/, $comment_uuid ],
    [ qr/id: (\d+) \($comment_uuid\)/, 
        qr/I hate you/,
        qr/created: /i,
        qr/creator: /i,
        "ticket: $yatta_uuid"
    ],
    [],
    "Found the comment new version"
);

run_output_matches(
    'sd',
    [ qw/ticket comment list --uuid/, $yatta_uuid ],
    [qr/$comment_uuid/],
    [],
    "Found the comment when we tried to search for all comments on a ticket by the ticket's uuid"
);
