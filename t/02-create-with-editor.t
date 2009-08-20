#!/usr/bin/perl -w
use strict;

use Prophet::Test tests => 13;
use App::SD::Test;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag 'export SD_REPO=' . $ENV{'PROPHET_REPO'} . "\n";
}
run_script( 'sd', [ 'init', '--non-interactive']);

my $replica_uuid = replica_uuid;

sub create_ticket_and_check {
    my %args = @_;

    my ($ticket_id, $ticket_uuid, $comment_id, $comment_uuid) = create_ticket_with_editor_ok(@{$args{extra_args}});

    run_output_matches( 'sd', [ 'ticket',
        'list', '--regex', '.' ],
        [ qr/(\d+) we are testing sd ticket create new/]
    ) if $args{check_sd_list};

    run_output_matches( 'sd', [ 'ticket', 'basics', '--batch', '--id', $ticket_id ],
        [
            "id: $ticket_id ($ticket_uuid)",
            'summary: we are testing sd ticket create',
            'status: new',
            'milestone: alpha',
            'component: core',
            qr/^created: \d{4}-\d{2}-\d{2}.+$/,
            qr/^creator: /,
            'reporter: ' . $ENV{PROPHET_EMAIL},
            "original_replica: $replica_uuid",
        ]
    );

    run_output_matches( 'sd', [ 'ticket', 'comment', 'show', '--batch', '--id', $comment_id ],
        [
            "id: $comment_id ($comment_uuid)",
            'content: template ok!',
            qr/^created: \d{4}-\d{2}-\d{2}.+$/,
            qr/^creator: /,
            "original_replica: $replica_uuid",
            qr/^ticket: $ticket_uuid$/,
        ]
    );
}

# test template for sd ticket create
Prophet::Test->set_editor_script("ticket-create-editor.pl --no-args $replica_uuid");
create_ticket_and_check(check_sd_list => 1);

# test template for sd ticket create --all-props
Prophet::Test->set_editor_script("ticket-create-editor.pl --all-props $replica_uuid");
create_ticket_and_check(extra_args => ['--all-props']);

# test template for sd ticket create --verbose
Prophet::Test->set_editor_script("ticket-create-editor.pl --verbose $replica_uuid");
create_ticket_and_check(extra_args => ['--verbose']);

# test template for sd ticket create --verbose --all-props
Prophet::Test->set_editor_script("ticket-create-editor.pl --verbose-and-all $replica_uuid");
create_ticket_and_check(extra_args => ['--all-props', '--verbose']);

