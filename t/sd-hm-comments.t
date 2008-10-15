#!/usr/bin/env perl
use warnings;
use strict;
use Prophet::Test;
use App::SD::Test;

BEGIN {
    if ( $ENV{'JIFTY_APP_ROOT'} ) {
        plan tests => 10;
        require File::Temp;
        $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
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
    summary     => "Fly Man",
    description => '',
);

diag $task->id;
my ( $ret, $out, $err );

my $sd_hm_url = "hm:$URL";
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_hm_url ] );

my ($flyman_uuid, $flyman_id );
{
    run_output_matches( 'sd', [qw(ticket list --regex .)], [qr/(.*?)(?{ $flyman_uuid = $1 }) Fly Man (.*)/] );
    ( $ret, $out, $err ) = run_script( 'sd', [ qw(ticket show --batch --id), $flyman_uuid ] );
    $flyman_id = $1 if $out =~ /^id: (\d+) /m;
}

my ( $comment_id, $comment_uuid ) = create_ticket_comment_ok(
    '--uuid', $flyman_uuid, '--content',
    "'This is a test'"
);

( $ret, $out, $err ) = run_script( 'sd', [ 'push','--to', $sd_hm_url ] );

