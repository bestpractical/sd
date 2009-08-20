#!/usr/bin/env perl
use warnings;
use strict;
use Prophet::Test;
use App::SD::Test;
$ENV{'PROPHET_EMAIL'} = 'onlooker@example.com';

BEGIN {
    if ( $ENV{'JIFTY_APP_ROOT'} ) {
        plan tests => 10;
        require File::Temp;
        $ENV{'PROPHET_REPO'} = $ENV{'SD_REPO'} = File::Temp::tempdir( CLEANUP => 1 ) . '/_svb';
        diag $ENV{'PROPHET_REPO'};
        eval "use Jifty";
        push @INC, File::Spec->catdir( Jifty::Util->app_root, "lib" );
    } else {
        plan skip_all => "You must define a JIFTY_APP_ROOT environment variable which points to your hiveminder source tree";
    }
}

eval 'use BTDT::Test; 1;' or die "$@";

run_script('sd', ['init', '--non-interactive']);

my $server = BTDT::Test->make_server;
my $URL    = $server->started_ok;
$URL =~ s{http://}{http://onlooker\@example.com:something@};
my $sd_hm_url = "hm:$URL";
diag $URL;

my $GOODUSER;
{
    my $root = BTDT::CurrentUser->superuser;
    my $as_root = BTDT::Model::User->new( current_user => $root );
    $as_root->load_by_cols( email => 'onlooker@example.com' );
    my ( $val, $msg ) = $as_root->set_accepted_eula_version( Jifty->config->app('EULAVersion') );
    ok( $val, $msg );
    ( $val, $msg ) = $as_root->set_pro_account(1);
    ok( $val, $msg );
    $GOODUSER = BTDT::CurrentUser->new( email => 'onlooker@example.com' );
    $GOODUSER->user_object->set_accepted_eula_version( Jifty->config->app('EULAVersion') );
}

my ($yatta_id, $yatta_uuid) =  create_ticket_ok( '--summary', 'YATTA', '--status', 'new' );

{
    my ($attachment_id, $attachment_uuid);
    run_output_matches('sd', [
        qw/ticket attachment create --uuid/, $yatta_uuid,
        '--content', 'stub', '--', '--name', "paper_order.doc"
        ], [
        qr/Created attachment (\d+)(?{ $attachment_id = $1}) \((.*)(?{ $attachment_uuid = $2})\)/
        ], [], "Added a attachment"
    );
    ok($attachment_id, " $attachment_id = $attachment_uuid");

    my ( $ret, $out, $err ) = run_script( 'sd', ['push', '--to', $sd_hm_url, '--force'] );
    diag $ret;
    diag $out;
    diag $err;

    my $task = BTDT::Model::Task->new( current_user => $GOODUSER );
    ok( $task->load_by_cols( summary => 'YATTA' ), "loaded a task" );

    my $attachments = $task->attachments;
    is( $attachments->count, 1, 'attachment has been pushed');
    my $attach = $attachments->first;

    is($attach->filename, 'paper_order.doc', 'filename is correct');
    is($attach->content, 'stub', 'correct content');
}
