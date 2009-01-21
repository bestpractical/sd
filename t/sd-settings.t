#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 2;
use App::SD::Test;
use Prophet::Util;
no warnings 'once';

# test the CLI and interactive UIs for showing and updating settings

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag $ENV{'PROPHET_REPO'};
}

run_script( 'sd', [ 'init']);


my $replica_uuid = replica_uuid;

# test noninteractive set
run_output_matches( 'sd', [ 'settings', '--set', '--', 'common_ticket_props',
    '["id","summary","original_replica"]' ],
    [
        'Trying to change common_ticket_props from ["id","summary","status","milestone","component","owner","created","due","creator","reporter","original_replica"] to ["id","summary","original_replica"].',
        'Changed common_ticket_props from ["id","summary","status","milestone","component","owner","created","due","creator","reporter","original_replica"] to ["id","summary","original_replica"].',
    ], [], "settings --set went ok",
);

# check with settings --show
my @valid_settings_output = Prophet::Util->slurp('t/data/sd-settings.tmpl');
chomp (@valid_settings_output);

run_output_matches(
    'sd',
    [ qw/settings --show/ ],
    [ @valid_settings_output ], [], "changed settings output matches"
);

# test sd settings (interactive editing)

# first set the editor to an editor script
# App::SD::Test->set_editor("ticket-update-editor.pl --verbose $replica_uuid $ticket_uuid");

# then edit the settings
# run_output_matches( 'sd', [ 'settings' ],
#     [
#         'Trying to change common_ticket_props from ["id","summary","status","milestone","component","owner","created","due","creator","reporter","original_replica"] to ["id","summary","original_replica"].',
#         'Changed common_ticket_props from ["id","summary","status","milestone","component","owner","created","due","creator","reporter","original_replica"] to ["id","summary","original_replica"].',
#     ], [], "interactive settings set went ok",
# );

# check the settings with settings --show

# test setting to invalid json
