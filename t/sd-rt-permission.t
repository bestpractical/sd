#!/usr/bin/env perl
# to run:
#
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/Users/clkao/work/bps/rt-3.7/lib t/sd-rt.t
use strict;
use warnings;
no warnings 'once';

# create a ticket as root, then try to pull it as someone who doesn't have the
# rights to see it

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

use Prophet::Test tests => 2;
use App::SD::Test;
use RT::Client::REST;
use RT::Client::REST::Ticket;

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );

my ( $url, $m ) = RT::Test->started_ok;

my $user = RT::Test->load_or_create_user(
    Name     => 'alice',
    Password => 'AlicesPassword',
);

my $root = RT::Client::REST->new( server => $url );
$root->login( username => 'root', password => 'password' );

my $ticket = RT::Client::REST::Ticket->new(
    rt      => $root,
    queue   => 'General',
    status  => 'new',
    subject => 'Fly Man',
)->store( text => "Ticket Comment" );

my $root_url = $url;
$root_url =~ s|http://|http://root:password@|;
my $sd_root_url = "rt:$root_url|General|Status!='resolved'";

my $alice_url = $url;
$alice_url =~ s|http://|http://alice:AlicesPassword@|;
my $sd_alice_url = "rt:$alice_url|General|Status!='resolved'";

as_alice {
    run_output_matches( 'sd', [ 'pull', '--from',  $sd_alice_url ],
        [
            qr/^Pulling from rt:/,
            "No new changesets.",
        ],
    );
};

