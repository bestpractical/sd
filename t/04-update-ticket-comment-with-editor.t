#!/usr/bin/perl -w
use strict;

use Prophet::Test tests => 5;
use App::SD::Test;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag 'export SD_REPO=' . $ENV{'PROPHET_REPO'} . "\n";
    Prophet::Test->set_editor_script('ticket-comment-update-editor.pl');
}

run_script( 'sd', [ 'init', '--non-interactive']);


my $replica_uuid = replica_uuid;

# create ticket
my ($ticket_id, $ticket_uuid) = create_ticket_ok( '--summary', 'zomg!' );

# create comment
my ($comment_id, $comment_uuid) = create_ticket_comment_ok(
    '--content' => 'a new comment', '--id' => $ticket_id
);

# verify that it's correct (test prop won't be shown)
run_output_matches( 'sd',
    [ 'ticket', 'comment', 'show', '--batch', '--id', $comment_id ],
    [
        "id: $comment_id ($comment_uuid)",
        qr/a new comment/,
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        qr/^creator: /,
        "original_replica: $replica_uuid",
        "ticket: $ticket_uuid",
    ]
);

# update it
App::SD::Test->update_ticket_comment_with_editor_ok($comment_id, $comment_uuid);

# check output
run_output_matches( 'sd',
    [ 'ticket', 'comment', 'show', '--batch', '--id', $comment_id ],
    [
        "id: $comment_id ($comment_uuid)",
        qr/huzzah!/,
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        qr/^creator: /,
        "original_replica: $replica_uuid",
        "ticket: $ticket_uuid",
    ]
);
