#!/usr/bin/env perl
package App::SD::CLI;
use Moose;
extends 'Prophet::CLI';

use App::SD;

has '+app_class' => (
    default => 'App::SD',
);

__PACKAGE__->meta->make_immutable;
no Moose;

1;

