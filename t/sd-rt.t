#!/usr/bin/perl -w

# to run:
#
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/Users/clkao/work/bps/rt-3.7/lib t/sd-rt.t
use strict;

use Test::More;
use Path::Class;
unless (eval 'use RT::Test; 1') {
    diag $@;
    plan skip_all => 'requires 3.7 or newer to run tests.';
}

eval 'use Prophet::Test tests => 23';
use App::SD::Test;

no warnings 'once';

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );
use Test::More;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    diag "export SD_REPO=".$ENV{'PROPHET_REPO'} ."\n";
}


my $IMAGE_FILE = qw|t/data/bplogo.gif|;


my ( $url, $m ) = RT::Test->started_ok;

use RT::Client::REST;
use RT::Client::REST::Ticket;
my $rt = RT::Client::REST->new( server => $url );
$rt->login( username => 'root', password => 'password' );

$url =~ s|http://|http://root:password@|;
my $sd_rt_url = "rt:$url|General|Status!='resolved'";

my $ticket = RT::Client::REST::Ticket->new(
    rt      => $rt,
    queue   => 'General',
    status  => 'new',
    subject => 'Fly Man',
)->store( text => "Ticket Comment" );

my ( $ret, $out, $err );
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from',  $sd_rt_url ] );
my ( $yatta_id, $flyman_id );
run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], 
    [qr/(.*?)(?{ $flyman_id = $1 }) Fly Man new/] );
RT::Client::REST::Ticket->new(
    rt     => $rt,
    id     => $ticket->id,
    status => 'open',
)->store();

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

run_output_matches( 'sd', [ 'ticket', 'list', '--regex', '.' ], ["$flyman_id Fly Man open"] );

# create from sd and push

run_output_matches(
    'sd',
    [ 'ticket', 'create', '--summary', 'YATTA', '--status', 'new' ],
    [qr/Created ticket (\d+)(?{ $yatta_id = $1 })/]
);

run_output_matches(
    'sd',
    [ 'ticket',                     'list', '--regex', '.' ],
    [ sort "$yatta_id YATTA new", "$flyman_id Fly Man open" ]
);

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
my @tix = $rt->search(
    type  => 'ticket',
    query => "Subject='YATTA'"
);

ok( scalar @tix, 'YATTA pushed' );

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

run_output_matches(
    'sd',
    [ 'ticket',                     'list', '--regex', '.' ],
    [ sort "$yatta_id YATTA new", "$flyman_id Fly Man open", ]
);

RT::Client::REST::Ticket->new(
    rt     => $rt,
    id     => $ticket->id,
    status => 'stalled',
)->store();

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

run_output_matches(
    'sd',
    [ 'ticket',                     'list', '--regex', '.' ],
    [ sort "$yatta_id YATTA new", "$flyman_id Fly Man stalled", ]
);

RT::Client::REST::Ticket->new(
    rt     => $rt,
    id     => $tix[0],
    status => 'open',
)->store();

diag( "===> bad pull");
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
run_output_matches(
    'sd',
    [ 'ticket',                      'list', '--regex', '.' ],
    [ sort "$yatta_id YATTA open", "$flyman_id Fly Man stalled", ]
);


my $tick = RT::Client::REST::Ticket->new(
    rt => $rt,
    id => $tix[0])->retrieve;

my ($val,$msg) = $tick->comment( message => 'this is a comment', attachments => [$IMAGE_FILE]);


my @attachments = get_rt_ticket_attachments($tix[0]);

is (scalar @attachments, 1, "Found our one attachment");

 
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
run_output_matches(
    'sd',
    [ 'ticket',                      'list', '--regex', '.' ],
    [ sort "$yatta_id YATTA open", "$flyman_id Fly Man stalled", ]
);

diag("check to see if YATTA has an attachment");


my $rt_attach_uuid;
run_output_matches( sd => [qw/ticket attachment list --id/, $yatta_id], [qr/(.*?)(?{ $rt_attach_uuid = $1 }) bplogo.gif image\/gif/] ); 
ok($rt_attach_uuid);

diag("Check to see if YATTA's attachment is binary-identical to the original one");

my $image_data = file($IMAGE_FILE)->slurp;
my ($contentret, $stdout, $stderr) = run_script('sd', [qw/attachment content --uuid/, $rt_attach_uuid]);
ok($contentret, "Ran the script ok");
is($stdout, $image_data, "We roundtripped some binary");
is($stderr, '');


diag("Add an attachment to YATTA");

my $MAKEFILE_CONTENT =    file('Makefile.PL')->slurp;
chomp($MAKEFILE_CONTENT); 
my $makefile_attach_uuid;
run_output_matches('sd', [qw/ticket attachment create --id/, $yatta_id, '--file', 'Makefile.PL'], [qr/Created attachment (\d+) \((.*?)(?{ $makefile_attach_uuid = $2})\)/], [], "Added a attachment");



my ($makefileret, $makefileout, $makefilerr) = run_script('sd', [qw/attachment content --uuid/, $makefile_attach_uuid]);
is($makefileout, $MAKEFILE_CONTENT, "We inserted the makefile correctly");

diag("Push the attachment to RT");

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );

diag("Check to see if the RT ticket has two attachments");
my @two_attachments = sort { $a->file_name cmp $b->file_name } get_rt_ticket_attachments($tix[0]);
is(scalar @two_attachments, 2, " I have two attachments on the RT side!");

my $makefile = shift @two_attachments;
my $logo = shift @two_attachments;


is ($logo->file_name, 'bplogo.gif');
is ($makefile->file_name, 'Makefile.PL');
is($makefile->content, $MAKEFILE_CONTENT , " The makefile's content was ropundtripped ot rt ok");

is($logo->content, file($IMAGE_FILE)->slurp, " The image's content was ropundtripped ot rt ok");


#diag $uuid;


exit();


sub get_rt_ticket_attachments {
    my $ticket = shift;

    my $attachments = RT::Client::REST::Ticket->new( rt => $rt, id => $ticket)->attachments();
    my $iterator = $attachments->get_iterator;
    my @attachments;
    while (my $att = &$iterator) { 
        if ( $att->file_name ) {
        push @attachments, $att ;
    }
    }
    return @attachments
}
1;

