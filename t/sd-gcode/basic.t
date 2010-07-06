#!/usr/bin/perl -w

use strict;
use warnings;
use Prophet::Test;

BEGIN {
    plan skip_all => "Tests require Net::Google::Code"
        unless eval { require Net::Google::Code; 1 };
}

plan tests => 10;
use App::SD::Test;

BEGIN {
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'}
        = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
    diag "export SD_REPO=" . $ENV{'PROPHET_REPO'} . "\n";
}

my $sd_gcode_url = "gcode:net-google-code";

my ( $ret, $out, $err );
( $ret, $out, $err ) =
  run_script( 'sd', [ 'clone', '--from', $sd_gcode_url, '--non-interactive' ] );
my $for_sd_id;

diag($err) if ($err);
run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', 'for sd test' ],
    [qr/(.*?)(?{ $for_sd_id = $1 }) for sd test accepted/]
);

( $ret, $out, $err ) =
  run_script( 'sd', [ 'ticket', 'comments', $for_sd_id ] );
diag($err) if ($err);

like( $out, qr/first comment.*second comment/s, 'comments pulled' );

( $ret, $out, $err ) = run_script( 'sd', [ 'attachment', 'list' ] );
diag($err) if ($err);
my ( $att_id ) = $out =~ /(\d+)\s*foo.txt/;
ok( $att_id, 'attachments pulled' );
( $ret, $out, $err ) = run_script( 'sd', [ 'attachment', 'content', $att_id ] );
diag($err) if ($err);
like( $out, qr/foobar/, 'attachment content' );

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', '--from', $sd_gcode_url ] );
diag($err) if ($err);

run_script( 'sd', [ 'ticket', 'comment', $for_sd_id, '-m', 'comment from sd' ] );

my $yatta_id;
run_output_matches(
    'sd',
    [ 'ticket', 'create', '--', '--summary', 'YATTA', '--status', 'new' ],
    [qr/Created ticket (\d+)(?{ $yatta_id = $1 })/]
);

run_output_matches(
    'sd',
    [ 'ticket', 'list', '--regex', 'YATTA' ],
    [qr/(.*?)(?{ $yatta_id = $1 }) YATTA new/]
);

( $ret, $out, $err ) =
  run_script( 'sd', [ 'push', '--to', $sd_gcode_url, '--dry-run' ] );
diag($err) if ($err);
diag($out);

like( $out, qr/"content" set to "comment from sd"/, 'comment pushed' );
like( $out, qr/"summary" set to "YATTA"/, 'ticket yatta pushed' );
unlike( $out, qr/test for sd/, 'pulled tickets not pushed' );
unlike( $out, qr/first comment.*second comment/s, 'pulled comments not pushed' );

