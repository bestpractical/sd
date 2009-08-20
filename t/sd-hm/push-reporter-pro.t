#!/usr/bin/env perl
use warnings;
use strict;
use Prophet::Test;
use App::SD::Test;

BEGIN {
    if ( $ENV{'JIFTY_APP_ROOT'} ) {
        plan tests => 23;
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

my $server = BTDT::Test->make_server;
my $URL    = $server->started_ok;
$URL =~ s|http://|http://onlooker\@example.com:something@|;
my $sd_hm_url = "hm:$URL";

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

diag($sd_hm_url);

# XXX: at this moment pros behave in the same way non-pro
{
    flush_sd();
    my ($luid, $uuid) = create_ticket_ok(qw(--summary YATTA --status new --reporter test@localhost));
    my ($ret, $out, $err) = run_script( 'sd', ['push', '--to', $sd_hm_url, '--force'] );
    my $task = load_new_hm_task();
    is $task->requestor->email, 'onlooker@example.com', 'correct email';

    my $comments = $task->comments;
    is( $comments->count, 2, "there are two comments" );
    my $comment = do { $comments->next; $comments->next->formatted_body };
    like( $comment, qr/test\@localhost/, "there is comment" );
}

diag("non pro have no right to change requestor");
{
    flush_sd();
    my ($luid, $uuid) = create_ticket_ok(qw(--summary YATTA --status new --reporter onlooker@example.com));
    update_ticket_ok($uuid, qw(--reporter test@localhost));
    my ($ret, $out, $err) = run_script( 'sd', ['push', '--to', $sd_hm_url] );
    diag($out,$err);
    my $task = load_new_hm_task();
    is $task->requestor->email, 'onlooker@example.com', 'correct email';

    my $comments = $task->comments;
    is( $comments->count, 2, "there are two comments" );
    my $comment = do { $comments->next; $comments->next->formatted_body };
    like( $comment, qr/test\@localhost/, "there is comment" );
}

diag("only one requestor");
{
    flush_sd();
    my ($luid, $uuid) = create_ticket_ok(qw(--summary YATTA --status new --reporter) ,'onlooker@example.com,test@localhost');
    my ($ret, $out, $err) = run_script( 'sd', ['push', '--to', $sd_hm_url] );

    like $err, qr/A ticket has more than one requestor when HM supports only one/, 'warning issued';

    my $task = load_new_hm_task();
    is $task->requestor->email, 'onlooker@example.com', 'correct email';

    my $comments = $task->comments;
    is( $comments->count, 2, "there are two comments" );
    my $comment = do { $comments->next; $comments->next->formatted_body };
    like( $comment, qr/test\@localhost/, "there is comment" );
}

# XXX: pretty much required
#diag("either pro or not can be a requestor");
#{
#    flush_sd();
#    my ($luid, $uuid) = create_ticket_ok(qw(--summary YATTA --status new --reporter onlooker@example.com));
#    my ($ret, $out, $err) = run_script( 'sd', ['push', '--to', $sd_hm_url] );
#
#    my $task = load_new_hm_task();
#    is $task->requestor->email, 'onlooker@example.com', 'correct email';
#}
#
#diag("pro users can set requestor");
#{
#    flush_sd();
#    my ($luid, $uuid) = create_ticket_ok(qw(--summary YATTA --status new --reporter test@localhost));
#    my ($ret, $out, $err) = run_script( 'sd', ['push', '--to', $sd_hm_url] );
#
#    my $task = load_new_hm_task();
#    is $task->requestor->email, 'test@localhost', 'correct email';
#}
#
#diag("pro users can set requestor, but hm supports only one requestor");
#{
#    flush_sd();
#    my ($luid, $uuid) = create_ticket_ok(qw(--summary YATTA --status new --reporter test@localhost,test2@localhost));
#    my ($ret, $out, $err) = run_script( 'sd', ['push', '--to', $sd_hm_url] );
#
#    my $task = load_new_hm_task();
#    is $task->requestor->email, 'test@localhost', 'correct email';
#
#    my $comments = $task->comments;
#    is( $comments->count, 2, "there are two comments" );
#    my $comment = do { $comments->next; $comments->next->formatted_body };
#    like( $comment, qr/test2\@localhost/, "there is comment" );
#}

sub flush_sd {
    use File::Path qw(rmtree);
    rmtree( $ENV{'SD_REPO'} );
    run_script( 'sd', ['init', '--non-interactive'] );
}

{ my %seen;
sub load_new_hm_task {
    my $tasks = BTDT::Model::TaskCollection->new( current_user => $GOODUSER );
    $tasks->limit( column => 'summary', value => 'YATTA' );
    $tasks->order_by( { column => 'id', order => 'desc' } );

    my $res = $tasks->first;
    my $hm_tid = $res->id;
    ok $hm_tid, "loaded hm task #$hm_tid";
    ok !$seen{$hm_tid}++, "not seen #$hm_tid";

    return $res;
} }

