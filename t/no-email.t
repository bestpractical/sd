#!/usr/bin/perl
use warnings;
use strict;

use Prophet::Test tests => 3;
use App::SD::Test;
use App::SD::CLI;
$Prophet::Test::CLI_CLASS = 'App::SD::CLI';

$ENV{'PROPHET_REPO'} = $Prophet::Test::REPO_BASE . '/repo-' . $$;
diag "Replica is in $ENV{PROPHET_REPO}";

run_command( 'init', '--non-interactive' );
is( run_command( 'config', 'user.email-address' ),
    "Key user.email-address is not set.\n", 'no email set' );

$ENV{PROPHET_EMAIL} = undef;
$ENV{EMAIL} = undef;

my @cmds = (
    {
        cmd     => [ 'claim', 'ticket', '1' ],
        error   => [
            'Could not determine email address to assign ticket to!',
            "Set the 'user.email-address' config variable.",
        ],
        comment => 'ticket claim w/no email set',
    },
    {
        cmd     => [ qw(ticket new -- summary foo) ],
        error   => [
            'Cannot determine an email to attribute your changes to. You can',
            "fix this by setting the config variable 'user.email-address'.",
        ],
        comment => 'trigger prop_default_reporter w/no email',
    },
);

for my $item ( @cmds ) {
    my $exp_error
        = defined $item->{error}
        ? (join "\n", @{$item->{error}})
        : '';
    my ($out, $got_error) = run_command( @{$item->{cmd}} );
    {
        local $/ = "";     # chomp paragraph mode
        chomp $got_error;
        chomp $exp_error;
    }
    is( $got_error, $exp_error, $item->{comment} );
}
