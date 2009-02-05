#!/usr/bin/env perl
package App::SD::CLI;
use Any::Moose;
extends 'Prophet::CLI';

use App::SD;
use App::SD::CLI::Dispatcher;

has '+app_class' => (
    default => 'App::SD',
);

sub dispatcher_class { "App::SD::CLI::Dispatcher" }

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

