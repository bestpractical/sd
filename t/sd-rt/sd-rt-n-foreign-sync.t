#!/usr/bin/env perl

# to run:
#
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/Users/clkao/work/bps/rt-3.7/lib t/sd-rt.t
use strict;
use warnings;
no warnings 'once';

# setup for rt
use Prophet::Test;
use App::SD::Test;

BEGIN {
     unless (eval 'use RT::Test tests => "no_declare"; 1;') {
        diag $@;
        plan skip_all => 'requires RT 3.8 to run tests.';
    }
}

BEGIN {
    unless ( $ENV{'JIFTY_APP_ROOT'} ) {
        plan skip_all => "You must define a JIFTY_APP_ROOT environment variable which points to your hiveminder source tree";
    }
    require File::Temp;
    eval "use Jifty;";
    push @INC, File::Spec->catdir( Jifty::Util->app_root, "lib" );
}

plan tests => 11;

use RT::Client::REST;
use RT::Client::REST::Ticket;

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );

eval 'use BTDT::Test; 1;' or die "$@";

my $server = BTDT::Test->make_server;
my $URL    = $server->started_ok;

$URL =~ s|http://|http://onlooker\@example.com:something@|;
my $sd_hm_url = "hm:$URL";

ok( 1, "Loaded the test script" );

my ( $url, $m ) = RT::Test->started_ok;
diag("RT server started at $url");

my $CF = RT::Test->load_or_create_custom_field(
    Name  => 'sd:no-foreign-sync',
    Queue => 'General',
    Type  => 'SelectSingle',
);
$CF->AddValue(
    Name        => 'ForbidForeignSync',
    Description => 'Using this flag will forbid syncing the ticket to other foreign replicas',
);
$CF->AddValue(
    Name        => 'AllowForeignSync',
    Description => 'Using this flag will allow syncing the ticket to other foreign replicas',
);

my $rt = RT::Client::REST->new( server => $url );
$rt->login( username => 'root', password => 'password' );

$url =~ s|http://|http://root:password@|;
my $sd_rt_url = "rt:$url|General|Status!='resolved'";

my $ticket = RT::Client::REST::Ticket->new(
    rt      => $rt,
    queue   => 'General',
    status  => 'new',
    subject => 'Fly Man',
    cf      => {
        'sd:no-foreign-sync' => 'ForbidForeignSync',
    },
)->store( text => "Ticket Comment" );

# setup for hm
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
    tags        => 'sd:no-foreign-sync',
);

my ( $bob_yatta_id, $bob_flyman_id, $flyman_uuid, $yatta_uuid, $alice_yatta_id, $alice_flyman_id );
my ( $ret, $out, $err );

# start with the same database
as_alice {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};

    run_script( 'sd', [ 'init', '--non-interactive' ]);
};

as_bob {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};

    ( $ret, $out, $err ) = run_script( 'sd',
        [ 'clone', '--from', repo_uri_for('alice'), '--non-interactive' ] );
};

# now the tests, bob syncs with rt, alice syncs with hm
as_alice {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};

    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_hm_url ] );
    diag($err) if ($err);
    run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], [qr/^(.*?)(?{ $alice_yatta_id = $1 }) YATTA .*/] );
    $yatta_uuid = get_uuid_for_luid($alice_yatta_id);
};

as_bob {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};

    run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], [] );

    diag("Bob pulling from RT");
    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
    diag($err) if ($err);
    run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], [qr/^(.*?)(?{ $bob_flyman_id = $1 }) Fly Man new/] );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', repo_uri_for('alice'), '--force' ] );

    $flyman_uuid = get_uuid_for_luid($bob_flyman_id);
    my $bob_yatta_id = get_luid_for_uuid($yatta_uuid);

    run_output_matches_unordered(
        'sd',
        [ 'ticket',                             'list', '--regex', '.' ],
        [ reverse sort "$bob_yatta_id YATTA open", "$bob_flyman_id Fly Man new" ]
    );


    diag("Bob pushing to RT");
    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
    diag($err) if ($err);
};

as_alice {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};
    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', repo_uri_for('bob'), '--force' ] );


    $alice_flyman_id = get_luid_for_uuid($flyman_uuid);

    run_output_matches_unordered(
        'sd',
        [ 'ticket',                             'list', '--regex', '.' ],
        [ sort "$alice_yatta_id YATTA open", "$alice_flyman_id Fly Man new" ]
    );
};

# try pushing Fly Man to Hiveminder
as_bob {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};

    diag("Bob pushing to Hiveminder");
    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_hm_url ] );
    diag($err) if ($err);
};

as_alice {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};

    diag("Alice pushing to Hiveminder");
    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_hm_url ] );
    diag($err) if ($err);
};

TODO: {
    local $TODO = "no-foreign-sync not yet specced";
    ok(!$task->load_by_cols(summary => "Fly Man"), "no 'Fly Man' ticket on HM because RT had the no-foreign-sync custom field");
}

# try pushing YATTA to RT
as_bob {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};

    diag("Bob pushing to RT");
    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
    diag($err) if ($err);
};

as_alice {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};

    diag("Alice pushing to RT");
    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
    diag($err) if ($err);
};

my @ids = $rt->search(
    type => 'ticket',
    query => "Subject LIKE 'YATTA'",
);
TODO: {
    local $TODO = "no-foreign-sync not yet specced";
    is(@ids, 0, "no YATTA ticket (from HM) in RT");
}

