#!/usr/bin/perl -i
use strict;
use warnings;

use Prophet::Util;

# perl script to trick Proc::InvokeEditor with for the settings command

my %tmpl_files = ( '--first' => 'sd-settings-first.tmpl',
                   '--second' => 'sd-settings-second.tmpl',
                 );

my $option = shift @ARGV;
my $tmpl_file = $tmpl_files{$option};

# the test script passes in a temp file for us to write whether the
# template is ok or not to
my $status_tmp_file = shift;

my @valid_template =
    Prophet::Util->slurp("t/data/$tmpl_file");

my @template = ();

while (<>) {
    push @template, $_;

    if ($option eq '--first') {
        s/(?<=^default_status: \[")new(?="\])/open/; # valid json change
        s/^default_milestone(?=: \["alpha"\])$/invalid_setting/; # changes setting name
        s/(?<=uuid: B)A(?=B613BD)/F/; # changes a UUID to an invalid one
        s/^project_name//; # deletes setting
    } elsif ($option eq '--second') {
        s/(?<=^default_component: \[")core(?="\])/ui/; # valid json change
        s/(?<=^default_milestone: \["alpha")]$//; # invalid json
    }
    print;
}

my $ok = 1;

my %seen;     # lookup table
my @vonly;    # answer

# build lookup table
@seen{@template} = ( );

for my $line (@valid_template) {
    push(@vonly, $line) unless exists $seen{$line};
}

# if anything is only in the valid template, we don't match
$ok = 0 if scalar @vonly;

open STATUSFILE, '>', $status_tmp_file;
$ok ? print STATUSFILE "ok!" : print STATUSFILE "not ok!";
close STATUSFILE;
