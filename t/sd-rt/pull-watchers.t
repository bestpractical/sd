#!/usr/bin/perl -w

# to run:
#
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/Users/clkao/work/bps/rt-3.7/lib t/sd-rt.t
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

plan tests => 91;
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

# create without requestor pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
    );
    ok $tid, "created ticket #$tid in RT";

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $flyman_id;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $flyman_id = $1 }) Fly Man new/]
    );
    ok $flyman_id, 'pulled ticket';

    my ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create with requestor, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Requestor => 'test@localhost',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'reporter'}, 'test@localhost',
        'correct requestor';

    my ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create with requestor+requestor, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Requestor => ['test@localhost', 'another@localhost'],
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'reporter'}, 'another@localhost, test@localhost',
        'correct requestors';

    my ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create, add requestor, pull
{
    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Requestor => 'test@localhost',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($res) = $ticket->AddWatcher( Type => 'Requestor', Email => 'another@localhost' );
    ok $res, "added requestor";

    flush_sd();
    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'reporter'}, 'another@localhost, test@localhost',
        'correct requestor';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create, pull, add requestor, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Requestor => 'test@localhost',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'reporter'}, 'test@localhost',
        'correct requestor';

    my ($res) = $ticket->AddWatcher( Type => 'Requestor', Email => 'another@localhost' );
    ok $res, "added requestor";

    ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'reporter'}, 'another@localhost, test@localhost',
        'correct requestor';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create without requestor, pull, add requestor, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    ok !$info->{'metadata'}{'reporter'}, 'correct requestor';

    my ($res) = $ticket->AddWatcher( Type => 'Requestor', Email => 'another@localhost' );
    ok $res, "added requestor";

    ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'reporter'}, 'another@localhost',
        'correct requestor';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create without requestor, add requestor, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($res) = $ticket->AddWatcher( Type => 'Requestor', Email => 'another@localhost' );
    ok $res, "added requestor";

    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'reporter'}, 'another@localhost',
        'correct requestor';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create, pull, del requestor, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Requestor => 'test@localhost',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'reporter'}, 'test@localhost',
        'correct requestor';

    my ($res) = $ticket->DeleteWatcher( Type => 'Requestor', Email => 'test@localhost' );
    ok $res, "deleted requestor";

    ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    $info = get_ticket_info($sd_tid);
    ok !$info->{'metadata'}{'reporter'}, 'correct requestor';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create with cc, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Cc => 'test@localhost',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'cc'}, 'test@localhost',
        'correct cc';

    my ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create with cc+cc, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Cc => ['test@localhost', 'another@localhost'],
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'cc'}, 'another@localhost, test@localhost',
        'correct ccs';

    my ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create, add cc, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Cc => 'test@localhost',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($res) = $ticket->AddWatcher( Type => 'Cc', Email => 'another@localhost' );
    ok $res, "added cc";

    flush_sd();
    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'cc'}, 'another@localhost, test@localhost',
        'correct cc';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create, pull, add cc, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Cc => 'test@localhost',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'cc'}, 'test@localhost',
        'correct cc';

    my ($res) = $ticket->AddWatcher( Type => 'Cc', Email => 'another@localhost' );
    ok $res, "added cc";

    ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'cc'}, 'another@localhost, test@localhost',
        'correct cc';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create without cc, pull, add cc, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    ok !$info->{'metadata'}{'cc'}, 'correct cc';

    my ($res) = $ticket->AddWatcher( Type => 'Cc', Email => 'another@localhost' );
    ok $res, "added cc";

    ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'cc'}, 'another@localhost',
        'correct cc';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create without cc, add cc, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($res) = $ticket->AddWatcher( Type => 'Cc', Email => 'another@localhost' );
    ok $res, "added cc";

    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'cc'}, 'another@localhost',
        'correct cc';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

# create, pull, del cc, pull
{
    flush_sd();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($rt_tid) = $ticket->Create(
        Queue => 'General', Status => 'new', Subject => 'Fly Man',
        Cc => 'test@localhost',
    );
    ok $rt_tid, "created ticket #$rt_tid in RT";

    my ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    my $sd_tid;
    run_output_matches(
        'sd', [qw(ticket list --regex .)],
        [qr/(.*?)(?{ $sd_tid = $1 }) Fly Man new/]
    );
    ok $sd_tid, 'pulled ticket';

    my $info = get_ticket_info($sd_tid);
    is $info->{'metadata'}{'cc'}, 'test@localhost',
        'correct cc';

    my ($res) = $ticket->DeleteWatcher( Type => 'Cc', Email => 'test@localhost' );
    ok $res, "deleted cc";

    ($ret, $out, $err) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

    $info = get_ticket_info($sd_tid);
    ok !$info->{'metadata'}{'cc'}, 'correct cc';

    ($res) = $ticket->SetStatus('deleted');
    ok $res, 'deleted ticket in RT';
}

sub flush_sd {
    rmtree( $ENV{'SD_REPO'} );
    run_script( 'sd', ['init', '--non-interactive' ] );
}

