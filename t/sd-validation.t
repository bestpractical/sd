#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 10;
use App::SD::Test;
no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    warn $ENV{'PROPHET_REPO'};
}
# create from sd and push
my ($yatta_id, $yatta_uuid) = create_ticket_ok(    '--summary', 'YATTA', '--status', 'new' );


run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [  qr/(\d+) YATTA new/]
);


is_script_output( 'sd', [ 'ticket',  
    'update', '--uuid', $yatta_uuid, '--', '--status', 'super'
    ],
   [undef],  # stdout
    [qr/Validation error for 'status': 'super' is not a valid status/], # stderr
    "Despite the magic power phrase of 'yatta', super is not a valid bug status"
);

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA new/]
);


is_script_output( 'sd', [ 'ticket',  
    'update', '--uuid', $yatta_uuid, '--', '--status', 'stalled'
    ],
   [qr/ticket \d+ \($yatta_uuid\) updated./], # stdout
   [], # stderr
   "Setting the status to stalled went ok"

);

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA stalled/]
);


my $sylar_uuid;
is_script_output( 'sd', [ 'ticket',
    'create', '--', '--summary', 'Sylar!', '--status', 'evil' ],
    [undef],
    [qr/Validation error for 'status': 'evil' is not a valid status/],
    "Sylar can't create an eeevil ticket"
);

run_output_matches( 'sd', [ 'ticket',  
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA stalled/]
);


is_script_output( 'sd', [ 'ticket',  
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





1;

