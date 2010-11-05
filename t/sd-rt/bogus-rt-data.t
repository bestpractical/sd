#!/usr/bin/perl -w

# to run:
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/opt/rt3/lib t/bogus-rt-data.t
use strict;

use Prophet::Test;

BEGIN {
    unless (eval 'use RT::Test tests => "no_declare"; 1') {
        diag $@ if $ENV{'TEST_VERBOSE'};
        plan skip_all => 'requires RT 3.8 or newer to run tests.';
    }
}

plan tests => 6;
use App::SD::Test;

no warnings 'once';

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );
use Prophet::Test;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

my $IMAGE_FILE = qw|t/data/bplogo.gif|;

$RT::Test::SKIP_REQUEST_WORK_AROUND = 1;


diag("This test file makes sure that when someone has messed with RT's internal history, prophet doesn't explode");

my ( $url, $m ) = RT::Test->started_ok;

use RT::Client::REST;
use RT::Client::REST::Ticket;
my $rt = RT::Client::REST->new( server => $url );
$rt->login( username => 'root', password => 'password' );

$url =~ s|http://|http://root:password@|;
my $sd_rt_url = "rt:$url|General|Status!='resolved'";

my $ticket = RT::Client::REST::Ticket->new(
    rt      => $rt,
    queue   => 'General',
    status  => 'new',
    subject => 'Fly Man',
)->store( text => "Ticket Comment" );

my $flyman_rt_id = $ticket->id;

my ( $ret, $out, $err );
( $ret, $out, $err )
    = run_script( 'sd',
        [ 'clone', '--from', $sd_rt_url, '--non-interactive' ] );
my ( $flyman_id );
run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', '.' ],
    [qr/(.*?)(?{ $flyman_id = $1 }) Fly Man new/]
);
RT::Client::REST::Ticket->new( rt     => $rt, id     => $ticket->id, status => 'open',)->store();
diag("AB");
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], ["$flyman_id Fly Man open"]);

# create from sd and push

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
diag($out);
diag($err);
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
diag("DE");
diag("FE");
RT::Client::REST::Ticket->new( rt     => $rt, id     => $ticket->id, status => 'stalled',)->store();

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
diag("XE");
run_output_matches_unordered(
    'sd',
    [ 'ticket',              'list', '--regex', '.' ],
    [ "$flyman_id Fly Man stalled", ]
);

$RT::Handle->dbh->do("UPDATE Tickets SET Status = 'rejected' WHERE id = ".$ticket->id);
RT::Client::REST::Ticket->new( rt     => $rt, id     => $ticket->id, status => 'open',)->store();

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url, '--prefer', 'from' ] );
ok( $ret, $out );
run_output_matches_unordered(
    'sd',
    [ 'ticket',              'list', '--regex', '.' ],
    [ "$flyman_id Fly Man open", ]
);
1;

