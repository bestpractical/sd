#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 10;
use App::SD::Test;
use File::Temp qw/tempdir/;
use Path::Class;


no warnings 'once';

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = $ENV{'HOME'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
    diag "export HOME=".$ENV{'PROPHET_REPO'} ."\n";
    delete $ENV{'PROPHET_APP_CONFIG'}; # clear this because Prophet::Test sets it
}

# Tests the config file order of preference laid out in App::SD::Config
run_script( 'sd', [ 'init']);



# create from sd
my ($yatta_id, $yatta_uuid) = create_ticket_ok( '--summary', 'YATTA');

# default config file
diag("Testing default config file\n");

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/(\d+) YATTA new/]
);

# override App::SD::Test
delete $ENV{'SD_CONFIG'};
delete $ENV{'PROPHET_APP_CONFIG'};

ok( ! $ENV{'SD_CONFIG'}, "SD_CONFIG env var has been cleared" );
ok( ! $ENV{'PROPHET_APP_CONFIG'}, "PROPHET_APP_CONFIG env var has been cleared" );

# Test from least-preferred to most preferred, leaving the least-preferred
# files in place to make sure the next-most-preferred file is preferred
# over all the files beneath it.

diag("Testing \$HOME/.prophetrc\n");

my $config_filename = $ENV{'HOME'} . '/.prophetrc';

App::SD::Test->write_to_file($config_filename,
    "summary_format_ticket = %4s },\$luid | %-11.11s,status | %-60.60s,summary\n");

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/\s+(\d+) } new         YATTA/]
);

diag("Testing PROPHET_APP_CONFIG\n");

$config_filename = $ENV{'HOME'} . '/config-test';
$ENV{'PROPHET_APP_CONFIG'} = $config_filename;

App::SD::Test->write_to_file($config_filename,
    "summary_format_ticket = %-9.9s,status | %-60.60s,summary\n");

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/new       YATTA/]
);

diag("Testing \$HOME/.sdrc\n");

$config_filename = $ENV{'HOME'} . '/.sdrc';

App::SD::Test->write_to_file($config_filename,
    "summary_format_ticket = %4s },\$luid | %-7.7s,status | %-60.60s,summary\n");

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/\s+(\d+) } new     YATTA/]
);

diag("Testing fs_root/prophetrc\n");

$config_filename = $ENV{'SD_REPO'} . '/prophetrc';

App::SD::Test->write_to_file($config_filename,
    "summary_format_ticket = %4s },\$luid | %-10.10s,status | %-60.60s,summary\n");

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/\s+(\d+) } new        YATTA/]
);

diag("Testing fs_root/sdrc\n");

$config_filename = $ENV{'SD_REPO'} . '/sdrc';

App::SD::Test->write_to_file($config_filename,
    "summary_format_ticket = %4s },\$luid | %-6.6s,status | %-60.60s,summary\n");

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/\s+(\d+) } new    YATTA/]
);

diag("Testing SD_CONFIG\n");

$ENV{'SD_CONFIG'} = 't/prophet_testing.conf';

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', '.' ],
    [ qr/(\d+) } new    YATTA /]
);
