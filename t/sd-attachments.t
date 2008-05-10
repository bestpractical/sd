#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 9;

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
run_output_matches('sd', [qw/ticket attachment create --uuid/, $yatta_uuid, '--content', 'stub', '--name', "paper_order.doc"], [qr/Created attachment (.*?)(?{ $attachment_uuid = $1})$/], [], "Added a attachment");
ok($attachment_uuid);

run_output_matches('sd', [qw/ticket attachment list --uuid/, $yatta_uuid], [$attachment_uuid .  ' paper_order.doc text/plain',], [], "Found the attachment");

run_output_matches(
    'sd',
    [ qw/ticket attachment show --uuid/, $attachment_uuid ],
    [   "id: $attachment_uuid",
        "content_type: text/plain",
        qr/paper_order.doc/,
        "ticket: $yatta_uuid"
    ],
    [],
    "Found the attachment"
);
run_output_matches(
    'sd',
    [   qw/ticket attachment update --uuid/, $attachment_uuid,
        qw/--name/,                          "plague_recipe.doc"
    ],
    [qr/attachment $attachment_uuid updated/],
    [],
    "updated the attachment"
);
run_output_matches(
    'sd',
    [ qw/ticket attachment show --uuid/, $attachment_uuid ],
    [   "id: $attachment_uuid",
        "content_type: text/plain",
        qr/plague_recipe.doc/,
        "ticket: $yatta_uuid"
    ],
    [],
    "Found the attachment new version"
);

run_output_matches(
    'sd',
    [ qw/ticket attachment list --uuid/, $yatta_uuid ],
    [qr/$attachment_uuid/],
    [],
    "Found the attachment when we tried to search for all attachments on a ticket by the ticket's uuid"
);
