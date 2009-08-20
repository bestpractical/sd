#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 10;
use App::SD::Test;
no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag $ENV{'PROPHET_REPO'};
}

run_script( 'sd', [ 'init', '--non-interactive']);


my $replica_uuid = replica_uuid;

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
    [ qr/^id: \d+ \($comment_uuid\)/, qr/^created: /, '', "'This is a test'",
    '' ], [], "Found the comment"
);

run_output_matches(
    'sd',
    [ qw/ticket comment show --batch --uuid/, $comment_uuid ],
    [   qr/id: (\d+) \($comment_uuid\)/,
        qr/This is a test/,
        qr/created: /,
        qr/creator: /,
        "original_replica: $replica_uuid",
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
    [qr/Comment \d+ \($comment_uuid\) updated/],
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
        "original_replica: $replica_uuid",
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
    "Found the comment $comment_uuid when we tried to search for all comments on a ticket by the ticket's uuid, $yatta_uuid"
);

run_output_matches(
    'sd',
    [   qw/ticket comment update --uuid/, $comment_uuid,
        '--',
        qw/--content/,                    "A\nmultiline\ncomment"
    ],
    [qr/Comment \d+ \($comment_uuid\) updated/],
    [],
    "updated the comment to a multiline content"
);

run_output_matches(
    'sd',
    [ qw/ticket comment show --batch --uuid/, $comment_uuid ],
    [ qr/id: (\d+) \($comment_uuid\)/, 
        qr/^content: A/,
        qr/^multiline$/,
        qr/^comment$/,
        qr/created: /i,
        qr/creator: /i,
        "original_replica: $replica_uuid",
        "ticket: $yatta_uuid"
    ],
    [],
    "Found the comment new version"
);
