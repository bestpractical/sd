use warnings;
use strict;

use Prophet::Test;
use App::SD::Test;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

unless (`which trac-admin`) { plan skip_all => 'You need trac installed to run the tests'; }
unless ( eval { require Net::Trac } ) {
    plan skip_all => 'You need Net::Trac installed to run the tests';
}
plan tests => 17;

use_ok('Net::Trac::Connection');
use_ok('Net::Trac::Ticket');
require 't/sd-trac/setup_trac.pl';

my $tr = Net::Trac::TestHarness->new();
ok( $tr->start_test_server(), "The server started!" );

my $trac = Net::Trac::Connection->new(
    url      => $tr->url,
    user     => 'hiro',
    password => 'yatta'
);

my $sd_trac_url = "trac:" . $tr->url;
$sd_trac_url =~ s|http://|http://hiro:yatta@|;

isa_ok( $trac, "Net::Trac::Connection" );
is( $trac->url, $tr->url );

is( count_tickets_in_trac(), 0 );

#
# Clone from trac
#

my ( $ret, $out, $err )
    = run_script( 'sd', [ 'clone', '--from', $sd_trac_url, '--non-interactive' ] );
is( count_tickets_in_sd(), 0 );
ok(!($?>>8), $out." ".$err);
#
# create a ticket in sd
#
my ( $yatta_id, $yatta_uuid ) = create_ticket_ok( '--summary', 'This ticket originated in SD' );

run_output_matches(
    'sd', [ 'ticket',
        'list', '--regex', 'This ticket originated in SD' ],
    [qr/(\d+) This ticket originated in SD new/]

);

run_output_matches(
    'sd',
    [ 'ticket', 'basics', '--batch', '--id', $yatta_id ],
    [   "id: $yatta_id ($yatta_uuid)",
        'summary: This ticket originated in SD',
        'status: new',
        'milestone: alpha',
        'component: core',
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        'creator: ' . $ENV{PROPHET_EMAIL},
        'reporter: ' . $ENV{PROPHET_EMAIL},
        "original_replica: " . replica_uuid,
    ]
);

is( count_tickets_in_sd(),   1 );
is( count_tickets_in_trac(), 0 );

#
# push our ticket to trac
#

($ret,$out,$err) = run_script( 'sd', [ 'push', '--to', $sd_trac_url ] );
ok(!($?>>8), $err);
is( count_tickets_in_trac(), 1 );

#
# pull from trac
#

($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_trac_url ] );
ok(!($? >> 8) , $err);
is( count_tickets_in_sd(), 1 );

sub count_tickets_in_sd {
    my $self = shift;
    my ( $ret, $out, $err ) = run_script( 'sd' => [ 'ticket', 'list', '--regex', '.' ], );
    my @lines = split( /\n/, $out );
    return scalar @lines;
}

sub count_tickets_in_trac {
    my $self    = shift;
    my $tickets = Net::Trac::TicketSearch->new( connection => $trac );
    my $result  = $tickets->query( summary => { not => 'nonsense' } );
    my $count   = scalar @{ $tickets->results };
    return $count;
}
