#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 9;
use App::SD::Test;
no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    warn "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}
# create from sd and push
my ($yatta_id, $yatta_uuid) =  create_ticket_ok( '--summary', 'YATTA', '--status', 'new' );

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/$yatta_id YATTA new/]
);

my $attachment_id;
my $attachment_uuid;
run_output_matches('sd', [qw/ticket attachment create --id/, $yatta_uuid, '--content', 'stub', '--name', "paper_order.doc"], [qr/Created attachment (\d+)(?{ $attachment_id = $1}) \((.*)(?{ $attachment_uuid = $2})\)/], [], "Added a attachment");
ok($attachment_id);

run_output_matches('sd', [qw/ticket attachment list --id/, $yatta_uuid], [qr/\d+ paper_order.doc text\/plain/,], [], "Found the attachment");

run_output_matches(
    'sd',
    [ qw/ticket attachment show --id/, $attachment_id ],
    [ 
    
        qr/id: $attachment_id \($attachment_uuid\)/, 
        "content_type: text/plain",
        qr/paper_order.doc/,
        "content: stub",
        "ticket: $yatta_uuid"
    ],
    [],
    "Found the attachment"
);
run_output_matches(
    'sd',
    [   qw/ticket attachment update --id/, $attachment_uuid,
        qw/--name/,                          "plague_recipe.doc"
    ],
    [qr/attachment $attachment_uuid updated/],
    [],
    "updated the attachment"
);
run_output_matches(
    'sd',
    [ qw/ticket attachment show --id/, $attachment_uuid ],
    [  
        qr/id: (\d+) \($attachment_uuid\)/, 
        "content_type: text/plain",
        qr/plague_recipe.doc/,
        "content: stub",
        "ticket: $yatta_uuid"
    ],
    [],
    "Found the attachment new version"
);

run_output_matches(
    'sd',
    [ qw/ticket attachment list --id/, $yatta_uuid ],
    [qr/plague_recipe/],
    [],
    "Found the attachment when we tried to search for all attachments on a ticket by the ticket's uuid"
);
