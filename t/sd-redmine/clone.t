#!/usr/bin/env perl -w
use strict;
use warnings;

use Prophet::Test;
use App::SD::Test;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';

    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

unless ( eval { require Net::Redmine } ) {
    plan skip_all => 'You need Net::Redmine installed to run the tests';
}

require 't/sd-redmine/net_redmine_test.pl';
my $r = new_redmine();

use Test::Cukes;
use Carp::Assert;

feature(<<FEATURES);
Feature: clone tickets from redmine server
  In order to manage redmine ticketes in local sd
  sd should be able clone redmine tickets

  Scenario: basic cloning
    Given I have at least five tickets on my redmine server.
    When I clone the redmine project with sd
    Then I should see at least five tickets.
FEATURES

Given qr/I have at least five tickets on my redmine server./, sub {
    my @tickets = $r->search_ticket()->results;
    if (@tickets < 5) {
        new_tickets($r, 5);
        @tickets = $r->search_ticket()->results;
    }

    assert(@tickets >= 5);
};

When qr/I clone the redmine project with sd/, sub {
    my $sd_redmine_url = "redmine:" . $r->connection->url;
    my $user = $r->connection->user;
    my $pass = $r->connection->password;
    $sd_redmine_url =~ s|http://|http://${user}:${pass}@|;
    my ( $ret, $out, $err ) = run_script( 'sd', [ 'clone', '--from', $sd_redmine_url ] );

    diag($err) if ($err);
};

Then qr/I should see at least five tickets./, sub {
    my ( $ret, $out, $err ) = run_script('sd' => [ 'ticket', 'list', '--regex', '.' ]);
    my @lines = split(/\n/,$out);

    diag($out);

    assert(0+@lines >= 5);
};

runtests;
