#!/usr/bin/perl -w

# to run:
#
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/Users/clkao/work/bps/rt-3.7/lib t/sd-rt.t
use strict;

# setup for rt
use Prophet::Test;

BEGIN {
    unless (eval 'use RT::Test; 1') {
        diag $@;
        plan skip_all => 'requires 3.7 to run tests.';
    }
}

BEGIN {
    unless ( $ENV{'JIFTY_APP_ROOT'} ) {
        die "You must define a JIFTY_APP_ROOT environment variable which points to your hiveminder source tree";
    }
    require File::Temp;
    use Jifty;
    push @INC, File::Spec->catdir( Jifty::Util->app_root, "lib" );
}

plan tests => 10;

RT::Test->import();

no warnings 'once';

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );

eval 'use BTDT::Test; 1;' or die "$@";

my $server = BTDT::Test->make_server;
my $URL    = $server->started_ok;

$URL =~ s|http://|http://onlooker\@example.com:something@|;
my $sd_hm_url = "hm:$URL";

ok( 1, "Loaded the test script" );

my ( $url, $m ) = RT::Test->started_ok;
diag("RT server started at $url");

use RT::Client::REST;
use RT::Client::REST::Ticket;
my $rt = RT::Client::REST->new( server => $url );
$rt->login( username => 'root', password => 'password' );

$url =~ s|http://|http://root:password@|;
warn $url;
my $sd_rt_url = "rt:$url|General|Status!='resolved'";

my $ticket = RT::Client::REST::Ticket->new(
    rt      => $rt,
    queue   => 'General',
    status  => 'new',
    subject => 'Fly Man',
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
);

my ( $yatta_uuid, $flyman_uuid );
my ( $ret, $out, $err );

# now the tests, bob syncs with rt, alice syncs with hm
as_alice {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};
    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', $sd_hm_url ] );
    diag($err) if ($err);
    run_output_matches( 'sd', [ 'ticket', '--list', '--regex', '.' ], [qr/(.*?)(?{ $yatta_uuid = $1 }) YATTA .*/] );
};

as_bob {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};
    run_output_matches( 'sd', [ 'ticket', '--list', '--regex', '.' ], [] );
    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', $sd_rt_url ] );
    diag($err) if ($err);
    run_output_matches( 'sd', [ 'ticket', '--list', '--regex', '.' ], [qr/(.*?)(?{ $flyman_uuid = $1 }) Fly Man new/] );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', repo_uri_for('alice') ] );
    run_output_matches(
        'sd',
        [ 'ticket',                             '--list', '--regex', '.' ],
        [ sort "$yatta_uuid YATTA (no status)", "$flyman_uuid Fly Man new", ]
    );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', $sd_rt_url ] );
    diag($err) if ($err);

    # XXX: to check YATTA ticket created in RT.
};

as_alice {
    local $ENV{SD_REPO} = $ENV{'PROPHET_REPO'};
    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', repo_uri_for('bob') ] );
    run_output_matches(
        'sd',
        [ 'ticket',                             '--list', '--regex', '.' ],
        [ sort "$yatta_uuid YATTA (no status)", "$flyman_uuid Fly Man new", ]
    );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', $sd_rt_url ] );

    ok( $task->load_by_cols( summary => 'Fly Man' ) );
};
exit(0);

__END__



use Test::More;

my ($url, $m) = RT::Test->started_ok;

use RT::Client::REST;
use RT::Client::REST::Ticket;
my $rt = RT::Client::REST->new( server => $url );
$rt->login( username => 'root', password => 'password' );

$url =~ s|http://|http://root:password@|;
warn $url;
my $sd_rt_url = "rt:$url|General|Status!='resolved'";

my $ticket = RT::Client::REST::Ticket->new(
        rt => $rt,
        queue => 'General',
        status => 'new',
        subject => 'Fly Man',
    )->store(text => "Ticket Comment");

diag $ticket->id;
my ($ret, $out, $err);
($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);
warn $err;
my ($yatta_uuid, $flyman_uuid);
run_output_matches('sd', ['ticket', '--list', '--regex', '.'], [qr/(.*?)(?{ $flyman_uuid = $1 }) Fly Man new/]);


RT::Client::REST::Ticket->new(
        rt => $rt,
        id => $ticket->id,
        status => 'open',
    )->store();

($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);

run_output_matches('sd', ['ticket', '--list', '--regex', '.'], ["$flyman_uuid Fly Man open"]);

# create from sd and push

run_output_matches('sd', ['ticket', '--create', '--summary', 'YATTA', '--status', 'new'], [qr/Created ticket (.*)(?{ $yatta_uuid = $1 })/]);

diag $yatta_uuid;

run_output_matches('sd', ['ticket', '--list', '--regex', '.'],
                   [ sort 
                    "$yatta_uuid YATTA new",
                     "$flyman_uuid Fly Man open",
                   ]);

($ret, $out, $err) = run_script('sd', ['push', $sd_rt_url]);
diag $err;
my @tix = $rt->search(
        type  => 'ticket',
        query => "Subject='YATTA'"
    );

ok(scalar @tix, 'YATTA pushed');

($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);

run_output_matches('sd', ['ticket', '--list', '--regex', '.'],
                   [ sort
                    "$yatta_uuid YATTA new",
                     "$flyman_uuid Fly Man open",
                   ]);

RT::Client::REST::Ticket->new(
        rt => $rt,
        id => $ticket->id,
        status => 'stalled',
    )->store();

($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);

run_output_matches('sd', ['ticket', '--list', '--regex', '.'],
                   [ sort
                    "$yatta_uuid YATTA new",
                     "$flyman_uuid Fly Man stalled",
                   ]);

RT::Client::REST::Ticket->new(
        rt => $rt,
        id => $tix[0],
        status => 'open',
    )->store();

warn "===> bad pull";
($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);
diag $err;
run_output_matches('sd', ['ticket', '--list', '--regex', '.'],
                   [ sort
                    "$yatta_uuid YATTA open",
                     "$flyman_uuid Fly Man stalled",
                   ]);

#diag $uuid;

1;




