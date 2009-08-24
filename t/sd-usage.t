#!/usr/bin/perl
use warnings;
use strict;

use Prophet::Test tests => 22;
use App::SD::Test;
use App::SD::CLI;
$Prophet::Test::CLI_CLASS = 'App::SD::CLI';

$ENV{'PROPHET_REPO'} = $Prophet::Test::REPO_BASE . '/repo-' . $$;
diag "Replica is in $ENV{PROPHET_REPO}";

# additional tests for SD-specific usage methods

run_command( 'init', '--non-interactive' );

my @cmds = (
    {
        cmd     => [ qw(ticket create -h) ],
        error   => [
            'usage: sd-usage.t ticket create -- summary=foo status=open',
            '       sd-usage.t ticket create [--edit]',
        ],
        comment => 'show usage',
    },
    {
        cmd     => [ qw(ticket comments -h) ],
        error   => [ 'usage: sd-usage.t ticket comments <ticket-id>' ],
        comment => 'ticket comments usage',
    },
    {
        cmd     => [ qw(ticket show -h) ],
        error   => [
            'usage: sd-usage.t ticket show <record-id> [options]',
            '',
            'Options are:',
            "    -a|--all-props      Show props even if they aren't common",
            "    -s|--skip-history   Don't show ticket history",
            '    -h|--with-history   Show ticket history even if disabled in config',
            '    -b|--batch',
        ],
        comment => 'ticket show usage',
    },
    {
        cmd     => [ qw(ticket details -h) ],
        error   => [
            'usage: sd-usage.t ticket details <record-id> [options]',
            '',
            'Options are:',
            "    -a|--all-props      Show props even if they aren't common",
            '    -b|--batch',
        ],
        comment => 'ticket details usage',
    },
    {
        cmd     => [ qw(ticket search -h) ],
        error   => [
            'usage: sd-usage.t ticket search',
            '       sd-usage.t ticket search -- summary=~foo status!~new|open',
        ],
        comment => 'ticket search usage',
    },
    {
        cmd     => [ qw(ticket ls -h) ],
        error   => [
            'usage: sd-usage.t ticket ls',
            '       sd-usage.t ticket ls -- summary=~foo status!~new|open',
        ],
        comment => 'ticket ls usage',
    },
    {
        cmd     => [ qw(ticket update -h) ],
        error   => [
            'usage: sd-usage.t ticket update <record-id> --edit [--all-props]',
            '       sd-usage.t ticket update <record-id> -- status=open',
        ],
        comment => 'ticket update usage',
    },
    {
        cmd     => [ qw(help -h) ],
        error   => [ 'usage: sd-usage.t help [<topic>]' ],
        comment => 'help usage',
    },
    {
        cmd     => [ qw(browser -h) ],
        error   => [ 'usage: sd-usage.t browser [--port <number>]' ],
        comment => 'browser usage',
    },
    {
        cmd     => [ qw(init -h) ],
        error   => [ 'usage: sd-usage.t init [--non-interactive]',
            '',
            'Options:',
            "    -n | --non-interactive - Don't prompt to edit settings or specify email",
            '                             address for new database',
        ],
        comment => 'init usage',
    },
    {
        cmd     => [ qw(clone -h) ],
        error   => [ 'usage: sd-usage.t clone --from <url> [--non-interactive]',
            '',
            'Options:',
            "    -n | --non-interactive - Don't prompt to specify email address for new",
            '                             database',
        ],
        comment => 'clone usage',
    },
);

my $in_interactive_shell = 0;

for my $item ( @cmds ) {
    my $exp_error
        = defined $item->{error}
        ? (join "\n", @{$item->{error}})
        : '';
    my (undef, $got_error) = run_command( @{$item->{cmd}} );
    {
        local $/ = "";     # chomp paragraph mode
        chomp $got_error;
        chomp $exp_error;
    }
    is( $got_error, $exp_error, $item->{comment} . ' (non-shell)' );
}

$in_interactive_shell = 1;

for my $item ( @cmds ) {
    my $exp_error
        = defined $item->{error}
        ? (join "\n", @{$item->{error}}) . "\n"
        : '';
    # in an interactive shell, usage messages shouldn't be printing a command
    # name
    $exp_error =~ s/sd-usage.t //g;
    my (undef, $got_error) = run_command( @{$item->{cmd}} );
    {
        local $/ = "";     # chomp paragraph mode
        chomp $got_error;
        chomp $exp_error;
    }
    is( $got_error, $exp_error, $item->{comment} . ' (in shell)');
}

no warnings 'redefine';
sub Prophet::CLI::interactive_shell {
    return $in_interactive_shell;
}

