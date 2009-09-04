#!/usr/bin/perl -w

use strict;
use warnings;
use Prophet::Test;

BEGIN {
    plan skip_all => "Tests require Net::Lighthouse"
      unless eval { require Net::Lighthouse; 1 };
    plan skip_all =>
      "Tests require \$ENV{SD_TEST_LIGHTHOUSE_PUSH_TOKEN} to be set"
      unless $ENV{SD_TEST_LIGHTHOUSE_PUSH_TOKEN};
}

plan tests => 20;
use App::SD::Test;
use Net::Lighthouse::Project;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

# let's create a ticket via api
my $project = Net::Lighthouse::Project->new(
    account => 'sunnavy',
    token   => $ENV{SD_TEST_LIGHTHOUSE_PUSH_TOKEN},
);
ok( $project->load( 'sd' ), 'load project sd' );
# we use $time as tag, so we just pull the ticket we want
my $time = time;
my $ticket = $project->ticket;
ok(
    $ticket->create(
        title => 'create remotely',
        body  => 'remote',
        tag   => $time
    ),
    'create ticket remotely'
);
ok( $ticket->update( body => 'comment remotely' ), 'update ticket remotely' );

my $sd_lighthouseg_url =
    'lighthouse:'
  . $ENV{SD_TEST_LIGHTHOUSE_PUSH_TOKEN}
  . '@sunnavy/sd/'
  . "tagged:$time";

my ( $ret, $out, $err );
( $ret, $out, $err ) =
  run_script( 'sd', [ 'clone', '--from', $sd_lighthouseg_url, '--non-interactive' ] );

my $first_id;
diag($err) if ($err);
run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', 'create remotely' ],
    [qr/(.*?)(?{ $first_id = $1 }) create remotely/]
);

( $ret, $out, $err ) =
  run_script( 'sd', [ 'ticket', 'comments', $first_id ] );
like( $out, qr/comment remotely/s, 'comments pulled' );

( $ret, $out, $err ) =
  run_script( 'sd', [ 'pull', '--from', $sd_lighthouseg_url, '--dry-run' ] );
diag($err);
unlike(
    $out, qr/(comment remotely).*\1/s, 'not pulling comments pulled again'
);

run_script( 'sd', [ 'ticket', 'comment', $first_id, '-m', 'comment from sd' ] );
( $ret, $out, $err ) =
  run_script( 'sd', [ 'push', '--to', $sd_lighthouseg_url, '--dry-run' ] );
like( $out, qr/"content" set to "comment from sd"/, 'comment to be pushed' );

# do real push
( $ret, $out, $err ) =
  run_script( 'sd', [ 'push', '--to', $sd_lighthouseg_url ] );
diag($out);
diag($err);

my $from_sd;
run_output_matches(
    'sd',
    [
        'ticket',         'create',   '--',   '--summary',
        'create from sd', '--status', 'open', '--tag',
        $time
    ],
    [qr/Created ticket (\d+)(?{ $from_sd = $1 })/]
);

run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', 'create from sd' ],
    [qr/(.*?)(?{ $from_sd = $1 }) create from sd/]
);

run_output_matches(
    'sd',
    [ 'ticket', 'comment', $from_sd, '-m', 'comment from sd', ],
    [qr/Created comment/]
);

( $ret, $out, $err ) =
  run_script( 'sd', [ 'push', '--to', $sd_lighthouseg_url, '--dry-run' ] );
diag($out);
diag($err);
like(
    $out,
    qr/"summary" set to "create from sd"/,
    "ticket $from_sd to be pushed"
);
like(
    $out,
    qr/"content" set to "comment from sd"/,
    "comment to $from_sd to be pushed"
);
unlike( $out, qr/create remotely/, 'pulled tickets not pushed' );
unlike( $out, qr/comment remotely/s, 'pulled comments not pushed' );

( $ret, $out, $err ) =
  run_script( 'sd', [ 'push', '--to', $sd_lighthouseg_url ] );
diag($out);
diag($err);


( $ret, $out, $err ) =
  run_script( 'sd', [ 'pull', '--from', $sd_lighthouseg_url, '--dry-run' ] );
unlike( $out, qr/create from sd/, 'pushed tickets not pulled' );
unlike( $out, qr/comment from sd/, 'pushed tickets not pulled' );
diag($err);

my @tickets = $project->tickets( query => "tagged:$time" );
for my $ticket ( @tickets ) {
    $ticket->load( $ticket->number );
    if ( $ticket->title =~ /create from sd/ ) {
        is( scalar @{ $ticket->versions }, 2, 'comment is pushed' );
        like(
            $ticket->versions->[1]->body,
            qr/comment from sd/,
            'check pushed comment body'
        );
    }
    ok( $ticket->delete, 'remote ticket ' . $ticket->number . ' is deleted' );
}

