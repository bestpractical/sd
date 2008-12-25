#!/usr/bin/perl
use warnings;
use strict;

BEGIN {
    use File::Temp qw(tempdir);
    $ENV{'PROPHET_REPO'} = tempdir( CLEANUP => 0 ) . '/repo-' . $$;

}

use Prophet::Test tests => 10;
use Test::WWW::Mechanize;
use JSON;

use_ok('App::SD::Model::Ticket');
use_ok('App::SD::CLI');
my $cli = App::SD::CLI->new;
my $app_handle = $cli->app_handle;
my $ua  = Test::WWW::Mechanize->new();

my $url_root = start_server();

sub url {
    return join( "/", $url_root, @_ );
}
diag(url());
$ua->get_ok( url('records.json') );
is( $ua->content, '[]' );

my $t = App::SD::Model::Ticket->new(app_handle => $app_handle);
my ($uuid) = $t->create( props => { summary => 'The server works'});
ok( $uuid, "Created record $uuid" );

$ua->get_ok( url('records.json') );
is( $ua->content, '["__prophet_db_settings","ticket"]' );

$ua->get_ok( url( 'records', 'ticket', $uuid . ".json" ) );

TODO {
    local $TODO =" need to set created date";
is( $ua->content, '{"original_replica":"'.$t->handle->uuid.'","creator":"'.$t->default_prop_creator.'","summary":"The server works","status":"new"}' );
};

$ua->get( url( 'records', 'ticket', "1234.json" ) );
is( $ua->status, '404' );

$ua->post_ok( url( 'records', 'ticket', $uuid . ".json" ), { status => 'open' } );

$ua->get_ok( url( 'records', 'ticket', $uuid . ".json" ) );
TODO {
    local $TODO =" need to set created date";
    is( $ua->content, '{"original_replica":"'.$t->handle->uuid.'","creator":"'.$t->default_prop_creator.'","summary":"The server works","status":"new"}' );
};

sub start_server {
my $server_cli = Prophet::CLI->new();
my $s   = App::SD::TestServer->new();
$server_cli->handle()->initialize;
$s->app_handle( $server_cli->app_handle );
my $url_root = $s->started_ok("start up my web server");
return $url_root;
}
package App::SD::TestServer;
use base qw/Test::HTTP::Server::Simple Prophet::Server/;


sub port { my $self = shift; $self->{_port} ||= int(rand(1024))+10000; return $self->{_port} }



1;
