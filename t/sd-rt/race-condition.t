#!/usr/bin/perl -w

# to run:
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/opt/rt3/lib t/race-condition.t
use strict;

use Prophet::Test;

BEGIN {
    unless (eval 'use RT::Test tests => "no_declare"; 1') {
        diag $@ if $ENV{'TEST_VERBOSE'};
        plan skip_all => 'requires RT 3.8 or newer to run tests.';
    }
}

plan tests => 8;
use App::SD::Test;

no warnings 'once';

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

my $IMAGE_FILE = qw|t/data/bplogo.gif|;

$RT::Test::SKIP_REQUEST_WORK_AROUND = 1;


my $reason = <<EOF;
Before this script started passing, the RT replica type would automatically mark any change that happened before or at the same time as a push as having originated in SD, so it wouldn't pull it back from RT. This includes changes made by scrips after ticket update
EOF

diag($reason);


my ( $url, $m ) = RT::Test->started_ok;

use RT::Client::REST;
use RT::Client::REST::Ticket;
my $rt = RT::Client::REST->new( server => $url );
$rt->login( username => 'root', password => 'password' );

$url =~ s|http://|http://root:password@|;
my $sd_rt_url = "rt:$url|General|Status!='resolved'";



# Create a ticket in RT
my $ticket = RT::Client::REST::Ticket->new(
    rt      => $rt,
    queue   => 'General',
    status  => 'new',
    subject => 'Fly Man',
)->store( text => "Initial ticket Comment" );

my $flyman_rt_id = $ticket->id;

ok($flyman_rt_id, "I created a new ticket in RT");




# pull to sd


my ( $ret, $out, $err );
( $ret, $out, $err )
    = run_script( 'sd',
        [ 'clone', '--from', $sd_rt_url, '--non-interactive' ] );
my ( $yatta_id, $flyman_id );


#   make sure ticket is new

run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], [qr/(.*?)(?{ $flyman_id = $1 }) Fly Man new/]);





# comment on ticket in sd

( $ret, $out, $err ) = run_script( 'sd', [ 'ticket', 'comment', $flyman_id, '--content', 'helium is a noble gas' ] );
ok( $ret, $out );
like( $out, qr/Created comment/ );





#   make sure ticket is new

run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], ["$flyman_id Fly Man new"]);

diag("About to push to RT");
# push to rt
{

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
    diag($err);

}



#   make sure ticket is open in rt, since after we commented the scrip popped it open.
{
    my $fetched_ticket = RT::Client::REST::Ticket->new(
        rt => $rt,
        id => $flyman_rt_id
    )->retrieve;

    is( $fetched_ticket->status, "open" );

}

#   pull to sd
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

#   make sure ticket is open
run_output_matches_unordered(
    'sd',
    [ 'ticket',              'list', '--regex', '.' ],
    [ "$flyman_id Fly Man open", ]
);

