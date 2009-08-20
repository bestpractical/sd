#!/usr/bin/env perl
# to run:
#
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/Users/clkao/work/bps/rt-3.7/lib t/sd-rt.t
use strict;
use warnings;
no warnings 'once';

use Prophet::Test;

BEGIN {
    unless (eval 'use RT::Test tests => "no_declare"; 1') {
        diag $@ if $ENV{'TEST_VERBOSE'};
        plan skip_all => 'requires RT 3.8 or newer to run tests.';
    }
}

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";

}

plan tests => 17;
use App::SD::Test;
use RT::Client::REST;
use RT::Client::REST::Ticket;

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );

my ($ret, $out, $err);
my ( $url, $m ) = RT::Test->started_ok;

my $alice = RT::Test->load_or_create_user(
    Name     => 'alice',
    Password => 'AlicesPassword',
);

my $refuge = RT::Test->load_or_create_queue(
    Name => 'Ticket Refuge',
);

my $root = RT::Client::REST->new( server => $url );
$root->login( username => 'root', password => 'password' );

diag("create a ticket as root, then try to pull it as someone who doesn't have the rights to see it");

my $ticket = RT::Client::REST::Ticket->new(
    rt       => $root,
    queue    => 'General',
    status   => 'new',
    subject  => 'Fly Man',
    priority => 10,
)->store(text => "Ticket Comment");
my $ticket_id = $ticket->id;

my $root_url = $url;
$root_url =~ s|http://|http://root:password@|;
my $sd_root_url = "rt:$root_url|General|Status!='resolved'";

my $alice_url = $url;
$alice_url =~ s|http://|http://alice:AlicesPassword@|;
my $alice_rt_url = "rt:$alice_url|General|Status!='resolved'";

as_alice {
    run_script( 'sd', [ 'init', '--non-interactive' ]);
    ($ret, $out, $err) = run_script('sd', ['pull', '--from',  $alice_rt_url, '--force']);
    ok($ret);

        like($err, qr/No tickets found/);
};
diag("grant read rights, ensure we can pull it");

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Load('General');

$alice->PrincipalObj->GrantRight(Right => 'SeeQueue',   Object => $queue);
$alice->PrincipalObj->GrantRight(Right => 'ShowTicket', Object => $queue);

my $flyman_id;
as_alice {
    ($ret, $out, $err) = run_script('sd', ['pull', '--from',  $alice_rt_url]);
    ok($ret);

    run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ],
        [qr/(.*?)(?{ $flyman_id = $1 }) Fly Man new/] );
};

diag("without write rights, ensure that trying to push it gives a sane error");

as_alice {
    run_output_matches('sd', ['ticket', 'update', $flyman_id, '--', 'priority=20'],
        [qr/ticket .*$flyman_id.* updated/i],
    );

    ($ret, $out, $err) = run_script('sd', ['push', '--to',  $alice_rt_url]);
    ok($ret);
    like($err, qr/You are not allowed to modify ticket $ticket_id/);

    SKIP: {
        skip "test needs fixing", 1;

        # we should know exactly how many changesets there are.. used to be 1,
        # now it's 13. one must fail to be merged but we can still report that
        # the others (up to but excluding the failure) were successfully merged
    }

    # try again to make sure we still have pending changesets
    ($ret, $out, $err) = run_script('sd', ['push', '--to',  $alice_rt_url]);

    TODO: {
        local $TODO = "we mark all changesets as merged even if some failed";
    }
};

$ticket = RT::Client::REST::Ticket->new(
    rt      => $root,
    id      => $ticket_id,
)->retrieve;

is($ticket->priority, 10, "ticket not updated");

diag("give write rights, try to push again");

$alice->PrincipalObj->GrantRight(Right => 'ModifyTicket', Object => $queue);

as_alice {
    ($ret, $out, $err) = run_script('sd', ['push', '--to',  $alice_rt_url]);
    ok($ret);
    TODO: {
        local $TODO = "Prophet thinks it already merged this changeset!";
    }
};

$ticket = RT::Client::REST::Ticket->new(
    rt      => $root,
    id      => $ticket_id,
)->retrieve;

TODO: {
    local $TODO = "ticket is NOT updated!";
    is($ticket->priority, 20, "ticket updated");
}

diag("move the ticket, ensure it doesn't just disappear");
$ticket = RT::Client::REST::Ticket->new(
    rt       => $root,
    id       => $ticket_id,
    queue    => $refuge->Id,
    status   => 'stalled',
)->store;

as_alice {
    ($ret, $out, $err) = run_script('sd', ['pull', '--from',  $alice_rt_url]);
    ok($ret);

    run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ],
        [qr/Fly Man new/] );
};

diag("update the moved ticket");
$alice->PrincipalObj->GrantRight(Right => 'ModifyTicket', Object => $refuge);
$alice->PrincipalObj->GrantRight(Right => 'SeeQueue',     Object => $refuge);
$alice->PrincipalObj->GrantRight(Right => 'ShowTicket',   Object => $refuge);

as_alice {
    run_output_matches('sd', ['ticket', 'resolve', $flyman_id],
        [qr/ticket .*$flyman_id.* updated/i],
    );

    ($ret, $out, $err) = run_script('sd', ['push', '--to',  $alice_rt_url]);
    ok($ret);
};

$ticket = RT::Client::REST::Ticket->new(
    rt       => $root,
    id       => $ticket_id,
)->retrieve;

is($ticket->status, 'resolved', "ticket is updated");

