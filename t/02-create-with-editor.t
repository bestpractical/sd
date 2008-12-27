#!/usr/bin/perl -w
use strict;

use Prophet::Test tests => 4;
use App::SD::Test;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag 'export SD_REPO=' . $ENV{'PROPHET_REPO'} . "\n";
    App::SD::Test->set_editor('ticket-create-editor.pl');
}
run_script( 'sd', [ 'init']);

my $replica_uuid = replica_uuid;
my ($ticket_id, $ticket_uuid, $comment_id, $comment_uuid) = create_ticket_with_editor_ok();

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/(\d+) creating tickets with an editor is totally awesome new/]
);

run_output_matches( 'sd', [ 'ticket', 'basics', '--batch', '--id', $ticket_id ],
    [
        "id: $ticket_id ($ticket_uuid)",
        'summary: creating tickets with an editor is totally awesome',
        'status: new',
        'milestone: alpha',
        'component: core',
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        qr/^creator: /,
        'reporter: ' . $ENV{EMAIL},
        "original_replica: $replica_uuid",
    ]
);

run_output_matches( 'sd', [ 'ticket', 'comment', 'show', '--batch', '--id', $comment_id ],
    [
        "id: $comment_id ($comment_uuid)",
        'content: We can create a comment at the same time.',
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        qr/^creator: /,
        "original_replica: $replica_uuid",
        qr/^ticket: $ticket_uuid$/,
    ]
);
