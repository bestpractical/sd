#!/usr/bin/env perl -w
use strict;

use Prophet::Test;
use App::SD::Test;

unless ( $] >= 5.010 ) {
    plan skip_all => 'You need at least Perl 5.010 to enable redmine support';
}

require File::Temp;
$ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";

unless ( eval { require Net::Redmine } ) {
    plan skip_all => 'You need Net::Redmine installed to run the tests';
}

require 't/sd-redmine/net_redmine_test.pl';

my $r = new_redmine();

plan tests => 1;

note "create 5 new tickets in redmine.";
my @tickets = new_tickets($r, 5);

note "- created tickets: " . join(",", map { $_->id } @tickets);

note "sd clone them, verify their summary text.";
my $sd_redmine_url = "redmine:" . $r->connection->url;
my $user = $r->connection->user;
my $pass = $r->connection->password;
$sd_redmine_url =~ s|http://|http://${user}:${pass}@|;

diag "sd clone --from ${sd_redmine_url} --non-interactive";

my ( $ret, $out, $err )
    = run_script( 'sd',
        [ 'clone', '--from', $sd_redmine_url, '--non-interactive' ] );
is(count_tickets_in_sd(),5, "the total cloned tickets is 5.");

note "close one of them, push it to server.";
( $ret, $out, $err ) = run_script( 'sd', [ "ticket", "update", $tickets[0]->id, "--", "status=Closed" ] );
like( $out, qr/^Ticket(.*)updated/ );
diag($out);
diag($err);

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_redmine_url ] );
diag($out);
diag($err);

note "verify the update with Net::Redmine";
my $ticket = $r->lookup(ticket => { id => $tickets[0]->id });

TODO: {
    local $TODO = 'write support is not yet implemented';

    is($ticket->status, "Closed");
};

##
sub count_tickets_in_sd {
    my $self = shift;

    my ( $ret, $out, $err ) = run_script(
        'sd' => [ 'ticket', 'list', '--regex', '.' ]
    );
    my @lines = split(/\n/,$out);
    return scalar @lines;
}
