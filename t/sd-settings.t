#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 8;
use App::SD::Test;
use Prophet::Util;
use File::Temp qw(tempfile);
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
        ' -> Changed.',
    ], [], "settings --set went ok",
);

# check with settings --show
my @valid_settings_output = Prophet::Util->slurp('t/data/sd-settings-first.tmpl');
chomp (@valid_settings_output);

run_output_matches(
    'sd',
    [ qw/settings --show/ ],
    [ @valid_settings_output ], [], "changed settings output matches"
);

# test sd settings (interactive editing)

(undef, my $filename) = tempfile();
diag ("interactive template status will be found in $filename");
# first set the editor to an editor script
App::SD::Test->set_editor("settings-editor.pl --first $filename");

# then edit the settings
run_output_matches( 'sd', [ 'settings' ],
    [
        'Setting with uuid "BFB613BD-9E25-4612-8DE3-21E4572859EA" does not exist.',
        'Changed default_status from ["new"] to ["open"].',
    ], [], "interactive settings set went ok",);

# check the tempfile to see if the template presented to the editor was correct
chomp(my $template_ok = Prophet::Util->slurp($filename));
is($template_ok, 'ok!', "interactive template was correct");

# check the settings with settings --show
@valid_settings_output = Prophet::Util->slurp('t/data/sd-settings-second.tmpl');
chomp (@valid_settings_output);

run_output_matches(
    'sd',
    [ qw/settings --show/ ],
    [ @valid_settings_output ], [], "changed settings output matches"
);

# test setting to invalid json
(undef, my $second_filename) = tempfile();
diag ("interactive template status will be found in $second_filename");
App::SD::Test->set_editor("settings-editor.pl --second $second_filename");
run_output_matches( 'sd', [ 'settings' ],
    [
        qr/^An error occured setting default_milestone to \["alpha":/,
        'Changed default_component from ["core"] to ["ui"].',
    ], [], "interactive settings set with JSON error went ok",
);

# check the tempfile to see if the template presented to the editor was correct
chomp($template_ok = Prophet::Util->slurp($filename));
is($template_ok, 'ok!', "interactive template was correct");

# check the settings with settings --show
@valid_settings_output = Prophet::Util->slurp('t/data/sd-settings-third.tmpl');
chomp (@valid_settings_output);

run_output_matches(
    'sd',
    [ qw/settings --show/ ],
    [ @valid_settings_output ], [], "changed settings output matches"
);
