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
plan tests => 21;

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

test_push_of_comment();
test_push_of_attachment();

sub test_push_of_attachment {

	my ($fh, $filename) = File::Temp::tempfile(SUFFIX => '.txt', UNLINK => 1);
	print $fh "TIMTOWTDI\n";
	close $fh;
	sleep 2; # to make trac happy
    ( $ret, $out, $err )
        = run_script( 'sd', [ 'ticket', 'attachment', 'create', $yatta_id, '--file', $filename ] );

    ok( !( $? >> 8 ), $err );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_trac_url ] );
    ok( !( $? >> 8 ), $err );
    diag($out);
    diag($err);
    is( count_tickets_in_trac(), 1 );
    my $tickets = Net::Trac::TicketSearch->new( connection => $trac );
    my $result = $tickets->query( summary => { not => 'nonsense' } );
    is( $tickets->results->[0]->attachments->[0]->content, 'TIMTOWTDI' );
}

sub test_push_of_comment {

    ( $ret, $out, $err )
        = run_script( 'sd', [ 'ticket', 'comment', $yatta_id, '--content', "The text of the comment." ] );

    ok( !( $? >> 8 ), $err );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_trac_url ] );
    ok( !( $? >> 8 ), $err );
    diag($out);
    diag($err);
    is( count_tickets_in_trac(), 1 );
    my $tickets = Net::Trac::TicketSearch->new( connection => $trac );
    my $result = $tickets->query( summary => { not => 'nonsense' } );
    like( $tickets->results->[0]->comments->[0]->content, qr/The text of the comment./ );
}


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
