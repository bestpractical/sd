#!/usr/bin/env perl -w
use strict;
use warnings;
use Prophet::Test;
use App::SD::Test;

BEGIN {
    unless ( eval { require 5.010 } ) {
        plan skip_all => 'You need perl 5.010 or above to run the tests';
    }
}

unless ( eval { require Net::Redmine } ) {
    plan skip_all => 'You need Net::Redmine installed to run the tests';
}

use Test::Cukes;
use Text::Greeking;
use File::Temp;

require 't/sd-redmine/net_redmine_test.pl';

# disable warning from HTML::From because it's too noisy.
$SIG{__WARN__} = sub {};

my $r = new_redmine();
my @tickets;
my $the_ticket_with_histories;

Given qr/a clean sd repo/ => sub {
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
};

Given qr/I have at least five tickets on my redmine server./, sub {
    @tickets = $r->search_ticket()->results;
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
    my ( $ret, $out, $err )
        = run_script( 'sd',
            [ 'clone', '--from', $sd_redmine_url, '--non-interactive' ] );

    diag($err) if ($err);
};

Then qr/I should see at least five tickets./, sub {
    my ( $ret, $out, $err ) = run_script('sd' => [ 'ticket', 'list', '--regex', '.' ]);
    my @lines = split(/\n/,$out);

    # diag($out);

    assert(0+@lines >= 5);
};

Given qr/there is one ticket contains several history entries/ => sub {
    my $t = $tickets[0];
    my $h = $t->histories;

    diag "the ticket with many histories is " . $t->id;

    if (@$h < 2) {
        for (1..3) {
            $t->note( "comment $_" );
            $t->save;
        }
        $t->refresh;
    }

    assert @{$t->histories} > 2;

    $the_ticket_with_histories = $t;
};

Then qr/the history entries should also be cloned as ticket transactions/ => sub {
    my ($ret, $out, $err) = run_script('sd' => [ 'ticket', 'list', '--regex', $the_ticket_with_histories->subject ]);
    my @lines = split(/\n/,$out);
    my $id = (split / /, $lines[0], "2")[0];

    ($ret, $out, $err) = run_script('sd' => [ 'ticket', 'comments', $id ]);

    # diag "---\n$out\n---";
    assert $out !~ m/^No comments found/m;
    assert $out =~ m/comment 1/;
    assert $out =~ m/comment 2/;
    assert $out =~ m/comment 3/;
};

runtests <<FEATURES;
Feature: clone tickets from redmine server
  In order to manage redmine ticketes in local sd
  sd should be able clone redmine tickets

  Scenario: basic cloning
    Given a clean sd repo
    And I have at least five tickets on my redmine server.
    When I clone the redmine project with sd
    Then I should see at least five tickets.

  Scenario: cloning tickets with several history entries
    Given a clean sd repo
    And I have at least five tickets on my redmine server.
    And there is one ticket contains several history entries
    When I clone the redmine project with sd
    Then I should see at least five tickets.
    And the history entries should also be cloned as ticket transactions

FEATURES
