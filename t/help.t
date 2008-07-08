#!/usr/bin/perl -w

use strict;

use Prophet::Test tests => 1;
use App::SD::Test;
use App::SD;
no warnings 'once';

my ($ret,$out,$err) = run_script( 'sd', [ 'help']);

like($out, qr/sd $App::SD::VERSION/sm);
