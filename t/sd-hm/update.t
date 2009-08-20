#!/usr/bin/env perl
use warnings;
use strict;
use Prophet::Test;
use App::SD::Test;
$ENV{'PROPHET_EMAIL'} = 'onlooker@example.com';

BEGIN {
    if ( $ENV{'JIFTY_APP_ROOT'} ) {
        plan tests => 7;
        require File::Temp;
        $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
        diag $ENV{'PROPHET_REPO'};
        eval "use Jifty";
        push @INC, File::Spec->catdir( Jifty::Util->app_root, "lib" );
    } else {
        plan skip_all => "You must define a JIFTY_APP_ROOT environment variable which points to your hiveminder source tree";
    }
}

eval 'use BTDT::Test; 1;' or die "$@";

my $server = BTDT::Test->make_server;
my $URL    = $server->started_ok;
$URL =~ s|http://|http://onlooker\@example.com:something@|;
my $sd_hm_url = "hm:$URL";

ok( 1, "Loaded the test script" );
my $root = BTDT::CurrentUser->superuser;
my $as_root = BTDT::Model::User->new( current_user => $root );
$as_root->load_by_cols( email => 'onlooker@example.com' );
my ( $val, $msg ) = $as_root->set_accepted_eula_version( Jifty->config->app('EULAVersion') );
ok( $val, $msg );
my $GOODUSER = BTDT::CurrentUser->new( email => 'onlooker@example.com' );
$GOODUSER->user_object->set_accepted_eula_version( Jifty->config->app('EULAVersion') );

my $task = BTDT::Model::Task->new( current_user => $GOODUSER );
$task->create(
    summary     => "YATTA",
    description => '',
);
my $remote_id = $task->id;

my ($yatta_uuid, $yatta_id);
{
    my ($ret, $out, $err)
        = run_script( 'sd',
            [ 'clone', '--from', $sd_hm_url, '--non-interactive' ] );

    run_output_matches( 'sd', [qw(ticket list --regex .)], [qr/(.*?)(?{ $yatta_uuid = $1 }) YATTA (.*)/] );
    ( $ret, $out, $err ) = run_script( 'sd', [ qw(ticket show --batch --id), $yatta_uuid ] );
    diag($out);
    diag($err);
    ($yatta_id, $yatta_uuid) = ($1, $2) if $out =~ /^id: (\d+)\s*\((.*)\)/m;
}

is_script_output( 'sd', [ qw(ticket update --uuid), $yatta_uuid, qw(-- --summary BLABLA) ],
    [qr/ticket \d+ \(\Q$yatta_uuid\E\) updated./i], # stdout
    [undef],             # stderr
    "updated summary"
);
{
    my ( $ret, $out, $err ) = run_script( 'sd', [ 'push','--to', $sd_hm_url ] );

    my $task = BTDT::Model::Task->new( current_user => $GOODUSER );
    ok( $task->load_by_cols( summary => 'BLABLA' ), "loaded a task" );
    is( $task->id, $remote_id, "the same task" );
}

