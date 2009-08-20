use warnings;
use strict;

use Prophet::Test;
use App::SD::Test;
use Test::Script::Run qw/:all/;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

unless (`which trac-admin`) { plan skip_all => 'You need trac installed to run the tests'; }
unless ( eval { require Net::Trac } ) {
    plan skip_all => 'You need Net::Trac installed to run the tests';
}
plan tests => 46;

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

is(count_tickets_in_trac(),0);


# 
# Create a ticket in trac
#

my $ticket = Net::Trac::Ticket->new( connection => $trac );
isa_ok( $ticket, 'Net::Trac::Ticket' );

ok( $ticket->create( summary => 'This product has only a moose, not a pony' ) );
is( $ticket->id, 1 );

is(count_tickets_in_trac(),1);


#
# Update a ticket in trac
#

can_ok( $ticket, 'load' );
ok( $ticket->load(1) );
like( $ticket->state->{'summary'}, qr/pony/ );
like( $ticket->summary, qr/moose/, "The summary looks like a moose" );

sleep 2; # to make trac happy
ok( $ticket->update( summary => 'The product does not contain a pony' ),
    "updated!" );
unlike( $ticket->summary, qr/moose/, "The summary does not look like a moose" );

my ($fh, $filename) = File::Temp::tempfile(SUFFIX => '.txt');
print $fh "TIMTOWTDI\n";
close $fh;
sleep 2; # to make trac happy
ok($ticket->attach( file => $filename ), "Attaching file.");

my $history = $ticket->history;
ok( $history, "The ticket has some history" );
my @entries = @{ $history->entries };
is( scalar @entries, 3, "There are 3 txns");
my $first   = shift @entries;
is( $first->category, 'Ticket' );

# 
# Clone from trac
#

my ( $ret, $out, $err );
( $ret, $out, $err )
    = run_script( 'sd', [ 'clone', '--from', $sd_trac_url, '--non-interactive' ] );

is(count_tickets_in_sd(),1);

diag($out);
diag($err);
my $pony_id;


#
# Check our clone from trac
#

run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', '.' ],
    [qr/(.*?)(?{ $pony_id = $1 }) The product does not contain a pony new/]
);

ok( $pony_id, "I got the ID of a pony - It's $pony_id" );

my ( $att_id, $att_name );
run_output_matches(
    'sd',
    [ 'attachment', 'list', ],
    [qr!(\d+)(?{ $att_id = $1 }) (\S+)(?{$att_name=$2}) text/plain!]
);

like( $filename, qr/$att_name/, 'filename of attachment' );

run_output_matches(
    'sd',
    [ 'attachment', 'content', $att_id ],
    [qr/TIMTOWTDI/]
);

run_ok( 'sd', [ 'settings', '-s' ] );
my $settings = last_script_stdout();
like(
    $settings,
    qr/active_statuses: \["new","accepted","assigned","reopened"\]/,
    'active statuses setting'
);

like( $settings,
qr/statuses: \["new","accepted","assigned","reopened","closed","fixed","invalid","wontfix","duplicate","worksforme","test_resolution"\]/,
'statuses setting'
);


# 
# Modify the ticket we pulled from trac

( $ret, $out, $err ) = run_script( 'sd', [ "ticket", "update", $pony_id, "--", "status=closed" ] );
like( $out, qr/^Ticket(.*)updated/ );
diag($out);
diag($err);
( $ret, $out, $err ) = run_script( 'sd' => [ "ticket", "basics", $pony_id, "--batch" ] );

like( $out, qr/status: closed/ );
diag("The pony is $pony_id");
my $new_ticket = Net::Trac::Ticket->new( connection => $trac );
ok( $new_ticket->load(1) );
is( $new_ticket->status, 'new', "The ticket is new before we push to trac" );

# 
# Push the changes to our ticket to trac
#

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_trac_url, '--prefer','source' ] );
diag($out);
diag($err);

# 
# Check the state of our ticket after we push to trac

is(count_tickets_in_trac(),1);
my $closed_ticket = Net::Trac::Ticket->new( connection => $trac );
ok( $closed_ticket->load(1) );
is( $closed_ticket->status, 'closed', "The ticket is closed after we push to trac" );

# 
# Push to trac a second time -- this should cause no updates
#

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_trac_url ] );
diag($out);
diag($err);

is(count_tickets_in_trac(),1);
is(count_tickets_in_sd(),1);

#
# create a second ticket in sd
#
my ($yatta_id, $yatta_uuid) = create_ticket_ok( '--summary', 'This ticket originated in SD');

run_output_matches( 'sd', [ 'ticket',
    'list', '--regex', 'This ticket originated in SD' ],
    [ qr/(\d+) This ticket originated in SD new/]

);

run_output_matches( 'sd', [ 'ticket', 'basics', '--batch', '--id', $yatta_id ],
    [
        "id: $yatta_id ($yatta_uuid)",
        'summary: This ticket originated in SD',
        'status: new',
        'milestone: alpha',
        'component: core',
        qr/^created: \d{4}-\d{2}-\d{2}.+$/,
        'creator: '. $ENV{PROPHET_EMAIL},
        'reporter: ' . $ENV{PROPHET_EMAIL},
        "original_replica: " . replica_uuid,
    ]
);

is(count_tickets_in_sd(),2);

#
# create a second ticket in trac
#

my $ticket2 = Net::Trac::Ticket->new( connection => $trac );
isa_ok( $ticket2, 'Net::Trac::Ticket' );
ok( $ticket2->create( summary => 'This product has only a moose, not a pony' ) );
is(count_tickets_in_trac(),2);


#
# pull the second ticket from trac
#
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_trac_url ] );
diag($out);
diag($err);

is(count_tickets_in_sd(),3);



sub count_tickets_in_sd {
    my $self = shift;

    my ( $ret, $out, $err ) = run_script( 'sd' =>
           [ 'ticket', 'list', '--regex', '.' ],
    );
    my @lines = split(/\n/,$out);
   return scalar @lines;
}

sub count_tickets_in_trac {
    my $self = shift;
    my $tickets = Net::Trac::TicketSearch->new( connection => $trac );
    my $result = $tickets->query( summary => {not => 'nonsense'});
    my $count = scalar @{$tickets->results};
    return $count
}
