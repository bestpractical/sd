#!/usr/bin/env perl
use warnings;
use strict;
use Prophet::Test;
use App::SD::Test;
use File::Path qw(rmtree);
$ENV{'PROPHET_EMAIL'} = 'onlooker@example.com';

BEGIN {
    if ( $ENV{'JIFTY_APP_ROOT'} ) {
        plan tests => 17;
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

ok( 1, "Loaded the test script" );
my $root = BTDT::CurrentUser->superuser;
my $as_root = BTDT::Model::User->new( current_user => $root );
$as_root->load_by_cols( email => 'onlooker@example.com' );
my ( $val, $msg ) = $as_root->set_accepted_eula_version( Jifty->config->app('EULAVersion') );
ok( $val, $msg );
( $val, $msg ) = $as_root->set_pro_account(1);
ok( $val, $msg );

my $GOODUSER = BTDT::CurrentUser->new( email => 'onlooker@example.com' );
$GOODUSER->user_object->set_accepted_eula_version( Jifty->config->app('EULAVersion') );

# create a group
my ($gname, $gid) = ('mygroup', 0);
{
    my $group = BTDT::Model::Group->new( current_user => $GOODUSER );
    $group->create( name => $gname );
    $gid = $group->id;
    ok( $gid, "created group #". $gid );
}

my $task = BTDT::Model::Task->new( current_user => $GOODUSER );
$task->create(
    summary     => "Fly Man",
    group       => $gid,
);

{
    my $task = BTDT::Model::Task->new( current_user => $GOODUSER );
    $task->create(
        summary     => "without the group",
    );
    diag $task->id;
}

my ( $ret, $out, $err );

my $sd_hm_url = "hm:$URL|group=$gid";

# pull
{
    eval { ( $ret, $out, $err )
        = run_script( 'sd',
            [ 'clone', '--from', $sd_hm_url, '--non-interactive' ] ) };
    diag($out);
    diag($err);
}

my ($flyman_uuid, $flyman_id );
{
    run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], [qr/(.*?)(?{ $flyman_uuid = $1 }) Fly Man (.*)/] );
    ( $ret, $out, $err ) = run_script( 'sd', [ 'ticket', 'show', '--batch', '--id', $flyman_uuid ] );
    $flyman_id = $1 if $out =~ /^id: (\d+) /m;
}

{
    $task->set_summary('Crash Man');
    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_hm_url ] );
    run_output_matches_unordered( 'sd', [ 'ticket', 'list', '--regex', '.' ], ["$flyman_uuid Crash Man open"] );
}


my ($yatta_id, $yatta_uuid) = create_ticket_ok( '--summary', 'YATTA', '--status', 'new' );

run_output_matches_unordered(
    'sd', [ qw(ticket list --regex .) ],
    [ "$yatta_id YATTA new", "$flyman_id Crash Man open" ]
);

{
    my ( $ret, $out, $err ) = run_script( 'sd', [ 'push','--to', $sd_hm_url ] );
    ok( $task->load_by_cols( summary => 'YATTA' ), "loaded HM task #". $task->id );
    is( $task->group->id, $gid, "is in correct group" );
}

{
    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_hm_url ] );
    run_output_matches_unordered(
        'sd', [ qw(ticket list --regex .) ],
        [ "$yatta_id YATTA new", "$flyman_id Crash Man open" ]
    );
}

{
    my @res = $task->set_summary('KILL');
    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_hm_url ] );
    run_output_matches_unordered(
        'sd', [ qw(ticket list --regex .) ],
        [ "$yatta_id KILL new", "$flyman_id Crash Man open" ]
    );
}

rmtree( $ENV{'SD_REPO'}, {keep_root => 1} );


$sd_hm_url = "hm:$URL|group=$gname";
# pull
{
    eval { ( $ret, $out, $err ) = run_script( 'sd',
            [ 'clone', '--from', $sd_hm_url, '--non-interactive' ] ) };
    TODO: { local $TODO = ' Investigate changeset count. Why do we have 2 extra?';
    like($out, qr/2 changesets/, "merged changes");
    };
}

{
    my ($yatta_id, $yatta_uuid) = create_ticket_ok( '--summary', 'BLABLA', '--status', 'new' );
    ( $ret, $out, $err ) = run_script( 'sd', [ 'push','--to', $sd_hm_url ] );
    ok( $task->load_by_cols( summary => 'BLABLA' ), "loaded HM task" );
    is( $task->group->id, $gid, "is in correct group" );
}

