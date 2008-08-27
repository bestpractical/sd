#!/usr/bin/env perl
# to run:
#
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/Users/clkao/work/bps/rt-3.7/lib t/sd-rt.t
use strict;
use warnings;
no warnings 'once';

use Test::More;

BEGIN {
    unless (eval 'use RT::Test; 1') {
        diag $@;
        plan skip_all => 'requires 3.7 or newer to run tests.';
    }
}

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}

use Prophet::Test tests => 11;
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

my $root = RT::Client::REST->new( server => $url );
$root->login( username => 'root', password => 'password' );

diag("create a ticket as root, then try to pull it as someone who doesn't have the rights to see it");

my $ticket = RT::Client::REST::Ticket->new(
    rt      => $root,
    queue   => 'General',
    status  => 'new',
    subject => 'Fly Man',
)->store(text => "Ticket Comment");
my $ticket_id = $ticket->id;

my $root_url = $url;
$root_url =~ s|http://|http://root:password@|;
my $sd_root_url = "rt:$root_url|General|Status!='resolved'";

my $alice_url = $url;
$alice_url =~ s|http://|http://alice:AlicesPassword@|;
my $sd_alice_url = "rt:$alice_url|General|Status!='resolved'";

as_alice {
    ($ret, $out, $err) = run_script('sd', ['pull', '--from',  $sd_alice_url]);
    ok($ret);
    like($out, qr/No new changesets/);

    TODO: {
        local $TODO = "not coming through for some reason";
        like($err, qr/No tickets found/);
    }
};

diag("grant read rights, ensure we can pull it");

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Load('General');

$alice->PrincipalObj->GrantRight(Right => 'SeeQueue',   Object => $queue);
$alice->PrincipalObj->GrantRight(Right => 'ShowTicket', Object => $queue);

my $flyman_id;
as_alice {
    ($ret, $out, $err) = run_script('sd', ['pull', '--from',  $sd_alice_url]);
    ok($ret);
    like($out, qr/Merged one changeset/);

    run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ],
        [qr/(.*?)(?{ $flyman_id = $1 }) Fly Man new/] );
};

diag("without write rights, ensure that trying to push it gives a sane error");

as_alice {
    run_output_matches('sd', ['ticket', 'update', $flyman_id, '--', 'priority=20'],
        [qr/ticket .*$flyman_id.* updated/],
    );

    ($ret, $out, $err) = run_script('sd', ['push', '--to',  $sd_alice_url]);
    ok($ret);
    like($err, qr/You are not allowed to modify ticket $ticket_id/);

    TODO: {
        local $TODO = "we report success even though it failed";
        unlike($out, qr/Merged one changeset/);
    }
};

