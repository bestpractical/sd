#!/usr/bin/perl
use warnings;
use strict;
use Test::HTTP::Server::Simple;

BEGIN {
    use File::Temp qw(tempdir);
    $ENV{'PROPHET_REPO'} = tempdir( CLEANUP => 0 ) . '/repo-' . $$;

}

use Prophet::Test tests => 16;
use App::SD::Server;
use Test::WWW::Mechanize;
use JSON;

use_ok('App::SD::Model::Ticket');
use_ok('App::SD::CLI');
my $cli        = App::SD::CLI->new;
my $app_handle = $cli->app_handle;
my $ua         = Test::WWW::Mechanize->new();

my $url_root = start_server();

sub url {
    return join( "/", $url_root, @_ );
}
diag( url() );
$ua->get_ok( url('records.json') );
is( $ua->content, '["__prophet_db_settings"]' );

my $t = App::SD::Model::Ticket->new( app_handle => $app_handle );
my ($uuid) = $t->create( props => { summary => 'The server works' } );
ok( $uuid, "Created record $uuid" );

$ua->get_ok( url('records.json') );
is( $ua->content, '["__prophet_db_settings","ticket"]' );

$ua->get_ok( url( 'records', 'ticket', $uuid . ".json" ) );

TODO: {
    local $TODO = " need to set created date";
    is( $ua->content,
              '{"original_replica":"'
            . $t->handle->uuid
            . '","creator":"'
            . $t->default_prop_creator
            . '","summary":"The server works","status":"new"}' );
}

$ua->get( url( 'records', 'ticket', "1234.json" ) );
is( $ua->status, '404' );

$ua->post_ok( url( 'records', 'ticket', $uuid . ".json" ), { status => 'open' } );

$ua->get_ok( url( 'records', 'ticket', $uuid . ".json" ) );
TODO: {
    local $TODO = " need to set created date";
    is( $ua->content,
              '{"original_replica":"'
            . $t->handle->uuid
            . '","creator":"'
            . $t->default_prop_creator
            . '","summary":"The server works","status":"new"}' );
}

$ua->get_ok( url() );
like( $ua->content, qr/SD for Your SD Project/ );



$ua->follow_link( text_regex => qr/New ticket/);
$ua->content_contains ('Create a new ticket');


sub start_server {
    my $server_cli = App::SD::CLI->new();
    my $s          = App::SD::Server->new();
    unshift @App::SD::Server::ISA, 'Test::HTTP::Server::Simple';
    $server_cli->handle()->initialize;
    $s->port( int( rand(10000) + 1024 ) );
    $s->app_handle( $server_cli->app_handle );
    my $url_root = $s->started_ok("start up my web server");
    return $url_root;
}

1;
