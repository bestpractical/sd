#!/usr/bin/perl -w

# to run:
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/opt/rt3/lib t/rt-auto-open-conflict.t
use strict;

use Prophet::Test;

BEGIN {
    unless (eval 'use RT::Test tests => "no_declare"; 1') {
        diag $@ if $ENV{'TEST_VERBOSE'};
        plan skip_all => 'requires RT 3.8 or newer to run tests.';
    }
}

plan tests => 10;
use App::SD::Test;

no warnings 'once';

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

my $IMAGE_FILE = qw|t/data/bplogo.gif|;

$RT::Test::SKIP_REQUEST_WORK_AROUND = 1;

my ( $url, $m ) = RT::Test->started_ok;

use RT::Client::REST;
use RT::Client::REST::Ticket;
my $rt = RT::Client::REST->new( server => $url );
$rt->login( username => 'root', password => 'password' );

$url =~ s|http://|http://root:password@|;
my $sd_rt_url = "rt:$url|General|Status!='resolved'";

my $ticket = RT::Client::REST::Ticket->new( rt      => $rt, queue   => 'General', status  => 'new', subject => 'helium',)->store( text => "Ticket Comment" );
diag("Clone from RT");
my ( $ret, $out, $err )
    = run_script( 'sd',
        [ 'clone', '--from', $sd_rt_url, '--non-interactive' ] );
ok( $ret, $out );
diag($err);
my $helium_id;
run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', 'helium' ],
    [qr/(.*?)(?{ $helium_id = $1 }) helium new/]
);

diag("Comment on ticket in sd");
( $ret, $out, $err ) = run_script( 'sd', [ 'ticket', 'comment', $helium_id, '--content', 'helium is a noble gas' ] );
ok( $ret, $out );
like( $out, qr/Created comment/ );
diag($out);
diag($err);
{    # resolve a ticket

    diag("Resolve a ticket in SD");
    ( $ret, $out, $err ) = run_script( 'sd', [ 'ticket', 'resolve', $helium_id ] );
    ok( $ret, $out );
    like( $out, qr/Ticket .* updated/ );
    sleep(1);
    diag("Push to rt");
    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url, '--prefer', 'source' ] );
    ok( $ret, $out );
    diag($err);
    sleep(1);
    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url, '--prefer', 'source'] );
    ok( $ret, $out );
    diag($err);
    my $fetched_ticket = RT::Client::REST::Ticket->new(
        rt => $rt,
        id => $ticket->id
    )->retrieve;

    warn "Ticket id is ".$ticket->id;
    is( $fetched_ticket->status, "resolved" );
}
