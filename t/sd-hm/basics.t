#!/usr/bin/env perl
use warnings;
use strict;
use Prophet::Test;
use App::SD::Test;
$ENV{'PROPHET_EMAIL'} = 'onlooker@example.com';

BEGIN {
    if ( $ENV{'JIFTY_APP_ROOT'} ) {
        plan tests => 9;
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
# specify username and password in URL
$URL =~ s|http://|http://onlooker\@example.com:something@|;

my $GOODUSER;
{
    my $root = BTDT::CurrentUser->superuser;
    my $as_root = BTDT::Model::User->new( current_user => $root );
    $as_root->load_by_cols( email => 'onlooker@example.com' );
    my ( $val, $msg ) = $as_root->set_accepted_eula_version( Jifty->config->app('EULAVersion') );
    ok( $val, $msg );
    $GOODUSER = BTDT::CurrentUser->new( email => 'onlooker@example.com' );
    $GOODUSER->user_object->set_accepted_eula_version( Jifty->config->app('EULAVersion') );
}

my $task = BTDT::Model::Task->new( current_user => $GOODUSER );
$task->create(
    summary     => "Fly Man",
    description => '',
);

diag $task->id;
my ( $ret, $out, $err );

my $sd_hm_url = "hm:$URL";
eval { ( $ret, $out, $err )
    = run_script( 'sd',
        [ 'clone', '--from', $sd_hm_url, '--non-interactive' ] ) };

my ($flyman_uuid, $flyman_id );
run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], [qr/(.*?)(?{ $flyman_uuid = $1 }) Fly Man (.*)/] );

$task->set_summary('Crash Man');

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_hm_url ] );

run_output_matches_unordered( 'sd', [ 'ticket', 'list', '--regex', '.' ], ["$flyman_uuid Crash Man open"] );


( $ret, $out, $err ) = run_script( 'sd', [ 'ticket', 'show', '--batch', '--id', $flyman_uuid ] );
if ($out =~ /^id: (\d+) /m) {
    $flyman_id = $1;
}

my ($yatta_id, $yatta_uuid) = create_ticket_ok( '--summary', 'YATTA', '--status', 'new' );

run_output_matches_unordered(
    'sd',
    [ 'ticket', 'list', '--regex', '.' ],
    [ sort  
        "$yatta_id YATTA new",
        "$flyman_id Crash Man open"
    
    ]
);

( $ret, $out, $err ) = run_script( 'sd', [ 'push','--to', $sd_hm_url ] );
diag $err;
ok( $task->load_by_cols( summary => 'YATTA' ) );

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from',$sd_hm_url ] );

run_output_matches_unordered(
    'sd',
    [ 'ticket',                     'list', '--regex', '.' ],
    [ sort "$yatta_id YATTA new", "$flyman_id Crash Man open" ]
);
diag("We did one pull from hm just fine");
$task->set_summary('KILL');
diag("pulling from hiveminder a second time");

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_hm_url ] );

run_output_matches_unordered(
    'sd',
    [ 'ticket',                    'list', '--regex', '.' ],
    [ sort "$yatta_id KILL new", "$flyman_id Crash Man open" ]
);
