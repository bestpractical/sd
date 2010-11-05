#!/usr/bin/perl -w

# to run:
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/opt/rt3/lib t/pull-owner.t
use strict;
use warnings;

use Prophet::Test;
use File::Path qw(rmtree);

BEGIN {
    unless (eval 'use RT::Test tests => "no_declare"; 1') {
        diag $@ if $ENV{'TEST_VERBOSE'};
        plan skip_all => 'requires RT 3.8 or newer to run tests.';
    }
}

plan tests => 26;
use App::SD::Test;

no warnings 'once';

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );
use Prophet::Test;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

my $IMAGE_FILE = qw|t/data/bplogo.gif|;

my ( $url, $m ) = RT::Test->started_ok;

use RT::Client::REST;
use RT::Client::REST::Ticket;
my $rt = RT::Client::REST->new( server => $url );
$rt->login( username => 'root', password => 'password' );

$url =~ s|http://|http://root:password@|;
my $sd_rt_url = "rt:$url|General|Status!='resolved'";

my $root = RT::User->new( $RT::SystemUser );
$root->LoadByEmail('root@localhost');
ok $root->id, 'loaded root';

{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
    );
    ok $tid, "created ticket #$tid in RT";

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    ok !$info->{'metadata'}{'owner'}, 'no owner';

    my ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Owner => $root->id,
    );
    ok $tid, "created ticket #$tid in RT";
    is $ticket->Owner, $root->id, 'owner is set';

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'owner'}, 'root@localhost', 'owner is set';

    my ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

{
    flush_sd();

    my $ticket = RT::Ticket->new( $root );
    my ($tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Owner => $root->id,
    );
    ok $tid, "created ticket #$tid in RT";
    is $ticket->Owner, $root->id, 'owner is set';

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my ($res, $msg) = $ticket->SetOwner( $RT::Nobody->id );
    ok $res, 'unset owner in RT' or diag "error: $msg";

    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $info = get_ticket_info($sd_tid);
    ok !$info->{'metadata'}{'owner'}, 'owner is not set';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}


{
    flush_sd();

    my $ticket = RT::Ticket->new( $root );
    my ($tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
    );
    ok $tid, "created ticket #$tid in RT";

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my ($res, $msg) = $ticket->SetOwner( $root->id );
    ok $res, 'set owner in RT' or diag "error: $msg";

    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'owner'}, 'root@localhost', 'owner is set';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

sub flush_sd {
    rmtree( $ENV{'SD_REPO'} );
    run_script( 'sd', ['init', '--non-interactive' ] );
}

