#!/usr/bin/env perl
package App::SD::CLI;
use Moose;
extends 'Prophet::CLI';

use App::SD;
use App::SD::CLI::Dispatcher;

has '+app_class' => (
    default => 'App::SD',
);

sub dispatcher { "App::SD::CLI::Dispatcher" }

__PACKAGE__->meta->make_immutable;
no Moose;

1;

