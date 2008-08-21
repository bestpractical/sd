#!/usr/bin/perl -w
use strict;

use Prophet::Test tests => 4;
use App::SD::Test;
use Cwd;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag 'export SD_REPO=' . $ENV{'PROPHET_REPO'} . "\n";
    # frob the editor to use a perl script instead of spawning vi/emacs/etc.
    undef $ENV{'VISUAL'};       # Proc::InvokeEditor checks this first
    $ENV{'EDITOR'} = File::Spec->catfile(getcwd(), 't', 'scripts', 'ticket-create-editor.pl');
    diag 'export EDITOR=' . $ENV{'EDITOR'} . "\n";
}

my ($ticket_id, $ticket_uuid, $comment_id, $comment_uuid) = App::SD::Test::create_ticket_with_editor_ok();

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/(\d+) creating tickets with an editor is totally awesome new/]
);

run_output_matches( 'sd', [ 'ticket', 'show', '--batch', '--id', $ticket_id ],
    [
        "id: $ticket_id ($ticket_uuid)",
        'summary: creating tickets with an editor is totally awesome',
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
