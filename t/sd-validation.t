#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 12;
use App::SD::Test;
no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
}

run_script( 'sd', [ 'init', '--non-interactive']);

# create from sd and push
my ($yatta_id, $yatta_uuid) = create_ticket_ok(    '--summary', 'YATTA', '--status', 'new' );


run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [  qr/(\d+) YATTA new/]
);

is_script_output( 'sd', [ 'ticket',  
    'update', '--uuid', $yatta_uuid, '--', '--status', 'super'
    ],
   [],  # stdout
    [qr/Validation error for 'status': 'super' is not a valid status/], # stderr
    "Despite the magic power phrase of 'yatta', super is not a valid bug status"
);

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA new/]
);

# regression test: when multiple errors are present they should be
# separated by newlines
run_output_matches( 'sd', [ 'ticket',  
    'update', '--uuid', $yatta_uuid, '--', '--status', 'super',
    '--component', 'awesome'
    ],
   [],  # stdout
    [qr/Validation error for 'component': 'awesome' is not a valid component/,
    qr/Validation error for 'status': 'super' is not a valid status/], # stderr
    "Despite the magic power phrase of 'yatta', super is not a valid bug status"
);

run_output_matches( 'sd', [ 'ticket',  
    'update', '--uuid', $yatta_uuid, '--', '--status', 'stalled'
    ],
   [qr/Ticket \d+ \($yatta_uuid\) updated./], # stdout
   [], # stderr
   "Setting the status to stalled went ok"

);

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA stalled/]
);


my $sylar_uuid;
run_output_matches( 'sd', [ 'ticket',
    'create', '--', '--summary', 'Sylar!', '--status', 'evil' ],
    [],
    [qr/Validation error for 'status': 'evil' is not a valid status/],
    "Sylar can't create an eeevil ticket"
);

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA stalled/]
);


run_output_matches( 'sd', [ 'ticket',  
    'update', '--uuid', $yatta_uuid, '--', '--status', ''
    ],
   [], # stdout
    [qr/Validation error for 'status': '' is not a valid status/], #stderr
   "Setting the status to stalled went ok"

);


run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA stalled/]
);


# check to make sure that we can force-set props
run_output_matches( 'sd', [ 'ticket',  
    'update', '--uuid', $yatta_uuid, '--', '--status', 'super!'
    ],
    [qr/Ticket $yatta_id \($yatta_uuid\) updated/], #stdout
   [], # stderr
   "we can force-set an invalid prop"
);


1;

