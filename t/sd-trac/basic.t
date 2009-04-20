use warnings; use strict;
use Prophet::Test;

use App::SD::Test;



BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}


unless (`which trac-admin`) { plan skip_all => 'You need trac installed to run the tests'; }
unless (eval { require Net::Trac} ) { plan skip_all => 'You need Net::Trac installed to run the tests'; }
plan tests => 18;


use_ok('Net::Trac::Connection');
use_ok('Net::Trac::Ticket');
require 't/sd-trac/setup_trac.pl';


my $tr = Net::Trac::TestHarness->new();

ok($tr->start_test_server(), "The server started!");


my $trac = Net::Trac::Connection->new(
    url      => $tr->url,
    user     => 'hiro',
    password => 'yatta'
);




my $sd_trac_url = "trac:".$tr->url;
$sd_trac_url =~ s|http://|http://hiro:yatta@|;


isa_ok( $trac, "Net::Trac::Connection" );
is($trac->url, $tr->url);
my $ticket = Net::Trac::Ticket->new( connection => $trac);
isa_ok($ticket, 'Net::Trac::Ticket');

ok($ticket->create(summary => 'This product has only a moose, not a pony'));
is($ticket->id, 1);

can_ok($ticket, 'load');
ok($ticket->load(1));
like($ticket->state->{'summary'}, qr/pony/);
like($ticket->summary, qr/moose/, "The summary looks like a moose");
ok( $ticket->update( summary => 'The product does not contain a pony' ), "updated!");
unlike($ticket->summary, qr/moose/, "The summary does not look like a moose");

my $history = $ticket->history;
ok($history, "The ticket has some history");
my @entries = @{$history->entries};
my $first = shift @entries;
is($entries[0], undef, "there is only one history entry. no create txn");
is ($first->category, 'Ticket');

my ( $ret, $out, $err );
( $ret, $out, $err ) = run_script( 'sd', [ 'clone', '--from', $sd_trac_url ] );

diag($out);
diag($err);
my $pony_id;

run_output_matches('sd',
    [ 'ticket', 'list', '--regex', '.' ],
    [qr/(.*?)(?{ $pony_id = $1 }) The product does not contain a pony new/]
);

ok($pony_id, "I got the ID of a pony - It's $pony_id");

($ret,$out,$err) = run_script('sd', ["ticket", "update", $pony_id ,"--", "status=closed"]);
like($out, qr/^Ticket(.*)updated/);
diag($out);
diag($err);
($ret,$out,$err) = run_script('sd' => ["ticket" ,"basics" ,$pony_id ,"--batch"]);

like($out, qr/status: closed/);

diag("The pony is $pony_id");
my $new_ticket = Net::Trac::Ticket->new( connection => $trac);
isa_ok($new_ticket, 'Net::Trac::Ticket');
ok($new_ticket->load(1));
is($new_ticket->status, 'new', "The ticket is new before we push to trac");

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_trac_url ] );
diag($out);
diag($err);


ok($new_ticket->load(1));
is($new_ticket->status, 'closed', "The ticket is closed after we push to trac");


