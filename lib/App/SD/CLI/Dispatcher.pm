#!/usr/bin/env perl
package App::SD::CLI::Dispatcher;
use strict;
use warnings;
use Prophet::CLI::Dispatcher -base;


on qr'^\?(.*)$' => sub {my $cmd = $1 || '';  run ('help'. $cmd,  @_); last_rule;};
on qr'^(about|copying)$' => sub { run('help '.$1, @_); last_rule;};                     

on qr{^(ticket|comment|attachment) \s+ (.*)}xi => sub {
    my %args = @_;
    $args{context}->set_arg(type => $1);
    run($2, %args);
};

on qr{.} => sub {
    my %args = @_;
    my $cli = $args{cli};

    my @possible_classes;

    # we want to dispatch on the original command "ticket attachment create"
    # AND on the command we received "create"
    for ([@{ $args{dispatching_on} }], [split ' ', $_]) {
        my @pieces = __PACKAGE__->resolve_builtin_aliases(@$_);

        while (@pieces) {
            push @possible_classes, "App::SD::CLI::Command::"
                                . join '::', @pieces;
            shift @pieces;
        }
    }

    for my $class (@possible_classes) {
        if ($cli->_try_to_load_cmd_class($class)) {
            return $args{got_command}->($class);
        }
    }

    next_rule;
};

1;

