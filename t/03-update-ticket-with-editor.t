#!/usr/bin/perl -w
use strict;

use Prophet::Test tests => 5;
use App::SD::Test;
use Cwd;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag 'export SD_REPO=' . $ENV{'PROPHET_REPO'} . "\n";
    # frob the editor to use a perl script instead of spawning vi/emacs/etc.
    undef $ENV{'VISUAL'};       # Proc::InvokeEditor checks this first
    $ENV{'EDITOR'} = File::Spec->catfile(getcwd(), 't', 'scripts', 'ticket-update-editor.pl');
    diag 'export EDITOR=' . $ENV{'EDITOR'} . "\n";
}

# create ticket
my ($ticket_id, $ticket_uuid) = create_ticket_ok( '--summary', 'zomg!',
    '--owner', 'foo@bar.com');

# verify that it's correct (test prop won't be shown)
run_output_matches( 'sd', [ 'ticket', 'show', '--batch', '--id', $ticket_id ],
    [
        "id: $ticket_id ($ticket_uuid)",
        'summary: zomg!',
        'status: new',
        'owner: foo@bar.com',
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        qr/^creator: .+@.+$/,
    ]
);

# update it
my ($comment_id, $comment_uuid) = App::SD::Test->update_ticket_with_editor_ok($ticket_id, $ticket_uuid);

# check output
run_output_matches( 'sd', [ 'ticket', 'show', '--batch', '--id', $ticket_id ],
    [
        "id: $ticket_id ($ticket_uuid)",
        'summary: summary changed',
        'status: new',
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        qr/^creator: .+@.+$/,
    ]
);

run_output_matches( 'sd', [ 'ticket', 'comment', 'show', '--batch', '--id', $comment_id ],
    [
        "id: $comment_id ($comment_uuid)",
        'content: We can create a comment at the same time.',
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        qr/^creator: .+@.+$/,
        qr/^ticket: $ticket_uuid$/,
    ]
);
