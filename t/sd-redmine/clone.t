#!/usr/bin/env perl -w
use strict;

use Prophet::Test;
use App::SD::Test;

require File::Temp;
$ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";

unless ( eval { require Net::Redmine } ) {
    plan skip_all => 'You need Net::Redmine installed to run the tests';
}

require 't/sd-redmine/net_redmine_test.pl';

my $r = new_redmine();

plan tests => 1;

my @tickets = new_tickets($r, 5);

note "created 5 tickets: " . join(",", map { $_->id } @tickets);
note "sd clone them, verify the ticket count.";

my $sd_redmine_url = "redmine:" . $r->connection->url;
my $user = $r->connection->user;
my $pass = $r->connection->password;
$sd_redmine_url =~ s|http://|http://${user}:${pass}@|;

diag "sd clone --from ${sd_redmine_url}";

my ( $ret, $out, $err ) = run_script( 'sd', [ 'clone', '--from', $sd_redmine_url ] );
is(count_tickets_in_sd(),5, "the total cloned tickets is 5.");

sub count_tickets_in_sd {
    my $self = shift;

    my ( $ret, $out, $err ) = run_script(
        'sd' => [ 'ticket', 'list', '--regex', '.' ]
    );
    my @lines = split(/\n/,$out);
    return scalar @lines;
}

