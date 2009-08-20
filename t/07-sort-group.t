#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 11;
use Prophet::Util;
use App::SD::Test;
use File::Temp qw/tempdir/;

no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}

run_script( 'sd', [ 'init', '--non-interactive']);

my $replica_uuid = replica_uuid;

# create from sd
my ($ticket_id, $ticket_uuid) = create_ticket_ok( '--summary', 'YATTA',
    '--owner', 'foo@bar.com');
my ($ticket_id_2, $ticket_uuid_2) = create_ticket_ok( '--summary', 'huzzah!',
    '--owner', 'alpha@bravo.org' );

diag('default -- no sorting, no grouping');
run_output_matches( 'sd', [ 'ticket', 'list' ],
    [ qr/(\d+) YATTA new/,
      qr/(\d+) huzzah! new/,
    ]
);

diag('using --sort owner');
run_output_matches( 'sd', [ 'ticket', 'list', '--sort', 'owner' ],
    [ qr/(\d+) huzzah! new/,
      qr/(\d+) YATTA new/,
    ]
);

my $config_filename = $ENV{'SD_REPO'} . '/config';
Prophet::Util->write_file(
    file => $config_filename, content => '
[ticket]
    default-sort = owner
');
$ENV{'SD_CONFIG'} = $config_filename;

diag('using ticket.default-sort = owner');
run_output_matches( 'sd', [ 'ticket', 'list' ],
    [ qr/(\d+) huzzah! new/,
      qr/(\d+) YATTA new/,
    ]
);

diag('blank sort arg shouldn\'t override valid default sort');
run_output_matches( 'sd', [ 'ticket', 'list', '--sort' ],
    [ qr/(\d+) huzzah! new/,
      qr/(\d+) YATTA new/,
    ]
);

diag('using ticket.default-sort = owner and --sort none');
run_output_matches( 'sd', [ 'ticket', 'list', '--sort', 'none' ],
    [ qr/(\d+) YATTA new/,
      qr/(\d+) huzzah! new/,
    ]
);

# grouping does not guarantee ordering as it keeps its result in
# a list. that's ok as we can still check that it's grouped.
diag('using --group owner');
run_output_matches( 'sd', [ 'ticket', 'list', '--group', 'owner' ],
    [ '',
      qr/(alpha\@bravo.org|foo\@bar.com)/,
      qr/(===============|===========)/,
      '',
      qr/((\d+) huzzah! new|(\d+) YATTA new)/,
      '',
      qr/(alpha\@bravo.org|foo\@bar.com)/,
      qr/(===============|===========)/,
      '',
      qr/((\d+) huzzah! new|(\d+) YATTA new)/,
    ]
);

diag('using ticket.default-group = owner');
Prophet::Util->write_file(
    file => $config_filename, content => '
[ticket]
    default-group = owner
');

run_output_matches( 'sd', [ 'ticket', 'list' ],
    [ '',
      qr/(alpha\@bravo.org|foo\@bar.com)/,
      qr/(===============|===========)/,
      '',
      qr/((\d+) huzzah! new|(\d+) YATTA new)/,
      '',
      qr/(alpha\@bravo.org|foo\@bar.com)/,
      qr/(===============|===========)/,
      '',
      qr/((\d+) huzzah! new|(\d+) YATTA new)/,
    ]
);

diag('blank group arg shouldn\'t override valid default grouping');
run_output_matches( 'sd', [ 'ticket', 'list', '--group' ],
    [ '',
      qr/(alpha\@bravo.org|foo\@bar.com)/,
      qr/(===============|===========)/,
      '',
      qr/((\d+) huzzah! new|(\d+) YATTA new)/,
      '',
      qr/(alpha\@bravo.org|foo\@bar.com)/,
      qr/(===============|===========)/,
      '',
      qr/((\d+) huzzah! new|(\d+) YATTA new)/,
    ]
);

diag('using ticket.default-group = owner and --group none');
run_output_matches( 'sd', [ 'ticket', 'list', '--group', 'none' ],
    [ qr/(\d+) YATTA new/,
      qr/(\d+) huzzah! new/,
    ]
);

# TODO: test both sorting and grouping at the same time?
# sort sorts tickets within a grouping but not the groupings themselves
