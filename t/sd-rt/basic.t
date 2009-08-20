#!/usr/bin/perl -w

# to run:
#
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/Users/clkao/work/bps/rt-3.7/lib t/sd-rt.t
use strict;

use Prophet::Test;

BEGIN {
    unless (eval 'use RT::Test tests => "no_declare"; 1') {
        diag $@ if $ENV{'TEST_VERBOSE'};
        plan skip_all => 'requires RT 3.8 or newer to run tests.';
    }
}

plan tests => 41;
use App::SD::Test;

no warnings 'once';

RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

my $IMAGE_FILE = qw|t/data/bplogo.gif|;

$RT::Test::SKIP_REQUEST_WORK_AROUND = 1;

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

my $flyman_rt_id = $ticket->id;

my ( $ret, $out, $err );
( $ret, $out, $err )
    = run_script( 'sd',
        [ 'clone', '--from', $sd_rt_url, '--non-interactive' ] );
my ( $yatta_id, $flyman_id );
diag($err) if ($err);
run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', '.' ],
    [qr/(.*?)(?{ $flyman_id = $1 }) Fly Man new/]
);
RT::Client::REST::Ticket->new(
    rt     => $rt,
    id     => $ticket->id,
    status => 'open',
)->store();

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
diag($err);

run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', '.' ],
    ["$flyman_id Fly Man open"]
);

# create from sd and push

run_output_matches(
    'sd',
    [ 'ticket', 'create', '--', '--summary', 'YATTA', '--status', 'new' ],
    [qr/Created ticket (\d+)(?{ $yatta_id = $1 })/]
);

run_output_matches_unordered(
    'sd',
    [ 'ticket',                   'list', '--regex', '.' ],
    [ sort "$yatta_id YATTA new", "$flyman_id Fly Man open" ]
);

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
diag($out);
diag($err);
my @tix = $rt->search(
    type  => 'ticket',
    query => "Subject='YATTA'"
);

ok( scalar @tix, 'YATTA pushed' );

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );

run_output_matches_unordered(
    'sd',
    [ 'ticket',              'list', '--regex', '.' ],
    [ "$yatta_id YATTA new", "$flyman_id Fly Man open", ]
);

RT::Client::REST::Ticket->new(
    rt     => $rt,
    id     => $ticket->id,
    status => 'stalled',
)->store();
diag("Making ".$ticket->id." stalled");
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
diag($out);
diag($err);
run_output_matches_unordered(
    'sd',
    [ 'ticket',              'list', '--regex', '.' ],
    [ "$yatta_id YATTA new", "$flyman_id Fly Man stalled", ]
);
( $ret, $out, $err ) = run_script( 'sd', [ 'ticket' ,'list', '--regex', '.']);

diag($out);
diag($err); 

RT::Client::REST::Ticket->new(
    rt     => $rt,
    id     => $tix[0],
    status => 'open',
)->store();

diag("===> bad pull");
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
run_output_matches_unordered(
    'sd',
    [ 'ticket',               'list', '--regex', '.' ],
    [ "$yatta_id YATTA open", "$flyman_id Fly Man stalled", ]
);

my $tick = RT::Client::REST::Ticket->new(
    rt => $rt,
    id => $tix[0]
)->retrieve;

my ( $val, $msg ) = $tick->comment(
    message     => 'this is a comment',
    attachments => [$IMAGE_FILE]
);

my @attachments = get_rt_ticket_attachments( $tix[0] );

is( scalar @attachments, 1, "Found our one attachment" );

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
run_output_matches_unordered(
    'sd',
    [ 'ticket',               'list', '--regex', '.' ],
    [ "$yatta_id YATTA open", "$flyman_id Fly Man stalled", ]
);

diag("check to see if YATTA has an attachment");

my $rt_attach_id;
run_output_matches(
    sd => [ qw/ticket attachment list --id/, $yatta_id ],
    [qr/(.*?)(?{ $rt_attach_id = $1 }) bplogo.gif image\/gif/]
);
ok($rt_attach_id);

diag(
    "Check to see if YATTA's attachment is binary-identical to the original one"
);

my $image_data = Prophet::Util->slurp( $IMAGE_FILE );
my ( $contentret, $stdout, $stderr )
    = run_script( 'sd', [ qw/attachment content --id/, $rt_attach_id ] );
ok( $contentret, "Ran the script ok" );
utf8::decode($stdout);
is( $stdout, $image_data, "We roundtripped some binary" );
is( $stderr, '' );

diag("Add an attachment to YATTA");

my $MAKEFILE_CONTENT = Prophet::Util->slurp('Makefile.PL');
chomp($MAKEFILE_CONTENT);
my $makefile_attach_uuid;
run_output_matches(
    'sd',
    [ qw/ticket attachment create --id/, $yatta_id, '--file', 'Makefile.PL' ],
    [qr/Created attachment (\d+) \((.*?)(?{ $makefile_attach_uuid = $2})\)/],
    [],
    "Added a attachment"
);

my ( $makefileret, $makefileout, $makefilerr )
    = run_script( 'sd',
    [ qw/attachment content --uuid/, $makefile_attach_uuid ] );
is( $makefileout, $MAKEFILE_CONTENT, "We inserted the makefile correctly" );

diag("Push the attachment to RT");

( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );

diag("Check to see if the RT ticket has two attachments");
my @two_attachments = sort { $a->file_name cmp $b->file_name }
    get_rt_ticket_attachments( $tix[0] );
is( scalar @two_attachments, 2, " I have two attachments on the RT side!" );

my $makefile = shift @two_attachments;
my $logo     = shift @two_attachments;

is( $logo->file_name,     'bplogo.gif' );
is( $makefile->file_name, 'Makefile.PL' );
is( $makefile->content, $MAKEFILE_CONTENT,
    " The makefile's content was roundtripped ot rt ok" );

is( $logo->content,
    scalar Prophet::Util->slurp( $IMAGE_FILE ),
    " The image's content was roundtripped ot rt ok"
);

#diag $uuid;
# testing adding CCs to tickets

$tick->add_cc('hiro@example.com');    # stored
my ( $tval, $tmsg ) = $tick->store;
ok( $tval, $tmsg );

my $fetched_tick = RT::Client::REST::Ticket->new(
    rt => $rt,
    id => $tick->id
)->retrieve;

diag( $fetched_tick->subject );
my (@x) = $fetched_tick->cc;
is_deeply( \@x, ['hiro@example.com'] );
( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
ok( $ret, $out );

( $ret, $out, $err )
    = run_script( 'sd', [ 'ticket', 'show', '--verbose', '--id', $yatta_id ] );

like( $out, qr/"cc"\s+set\s+to\s+"hiro\@example.com"/ );

diag("resolve and comment on a ticket");

$ticket = RT::Client::REST::Ticket->new(
    rt      => $rt,
    queue   => 'General',
    status  => 'new',
    subject => 'helium',
)->store( text => "Ticket Comment" );

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
ok( $ret, $out );

my $helium_id;
run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', 'helium' ],
    [qr/(.*?)(?{ $helium_id = $1 }) helium new/]
);

( $ret, $out, $err )
    = run_script( 'sd',
    [ 'ticket', 'comment', $helium_id, '--content', 'helium is a noble gas' ] );
ok( $ret, $out );
like( $out, qr/Created comment/ );


{    # resolve a ticket
    ( $ret, $out, $err )
        = run_script( 'sd', [ 'ticket', 'resolve', $helium_id ] );
    ok( $ret, $out );
    like( $out, qr/Ticket .* updated/ );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
    ok( $ret, $out );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
    ok( $ret, $out );

    my $fetched_ticket = RT::Client::REST::Ticket->new(
        rt => $rt,
        id => $ticket->id
    )->retrieve;

    is( $fetched_ticket->status, "resolved" );
}

{    # delete a ticket for reals
    ( $ret, $out, $err )
        = run_script( 'sd', [ 'ticket','delete', $flyman_id]);
    ok( $ret, $out );
    like( $out, qr/Ticket .* deleted/i );

    ( $ret, $out, $err ) = run_script( 'sd', [ 'push', '--to', $sd_rt_url ] );
    ok( $ret, $out );
    diag($out);
    ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_rt_url ] );
    ok( $ret, $out );

    my $fetched_ticket = RT::Client::REST::Ticket->new(
        rt => $rt,
        id => $flyman_rt_id 
    )->retrieve;
    TODO: {
    local $TODO = "Deleting tickets in RT still doesn't play nicely with SD";
    is( $fetched_ticket->status, "deleted" );
}
}






sub get_rt_ticket_attachments {
    my $ticket = shift;

    my $attachments = RT::Client::REST::Ticket->new( rt => $rt, id => $ticket )
        ->attachments();
    my $iterator = $attachments->get_iterator;
    my @attachments;
    while ( my $att = &$iterator ) {
        if ( $att->file_name ) {
            push @attachments, $att;
        }
    }
    return @attachments;
}

1;

