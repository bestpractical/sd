#!/usr/bin/env perl
package App::SD::CLI::Dispatcher;
use strict;
use warnings;
use Prophet::CLI::Dispatcher -base;

on qr{^(ticket|comment|attachment) \s+ (.*)}xi => sub {
    my %args = @_;
    $args{context}->set_arg(type => $1);
    run($2, %args);
};

on qr{.} => sub {
    my %args = @_;

    my @pieces = __PACKAGE__->resolve_builtin_aliases(@{ $args{dispatching_on} });

    my @possible_classes;
    while (@pieces) {
        push @possible_classes, "App::SD::CLI::Command::"
                              . join '::', @pieces;
        shift @pieces;
    }

    my $cli = $args{cli};

    for my $class (@possible_classes) {
        if ($cli->_try_to_load_cmd_class($class)) {
            return $args{got_command}->($class);
        }
    }

    next_rule;
};

1;

