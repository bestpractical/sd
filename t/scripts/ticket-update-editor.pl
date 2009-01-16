#!/usr/bin/perl -i
use strict;
use warnings;

use Prophet::Util;

# perl script to trick Proc::InvokeEditor with for the ticket update command

my $template = '';

my %tmpl_files = ( '--no-args' => 'sd-ticket-update.tmpl',
                   '--all-props' => 'sd-ticket-update-all-props.tmpl',
                   '--verbose' => 'sd-ticket-update-verbose.tmpl',
                   '--verbose-and-all' => 'sd-ticket-update-verbose-all-props.tmpl',
                 );

my $option = shift @ARGV;
my $tmpl_file = $tmpl_files{$option};

my $valid_template =
    Prophet::Util->slurp("t/data/$tmpl_file");

my $replica_uuid = shift @ARGV;
my $ticket_uuid = shift @ARGV;

# open DEBUG, '>', '/home/spang/tmp/got.txt';
# open DEBUG2, '>', '/home/spang/tmp/wanted.txt';

while (<>) {
    $template .= $_;

    if ($option eq '--no-args') {
        s/(?<=^summary: ).*$/summary changed/;
        s/^owner:.*$//;               # deleting a prop
        s/(?<=^due: ).*$/2050-01-25 23:11:42/; # adding a prop
    } elsif ($option eq '--all-props') {
        s/(?<=summary: ).*$/now we are checking --all-props/;
        s/^due:.*//;              # deleting a prop
        s/(?<=^owner: ).*$/$ENV{EMAIL}/; # adding a prop
    } elsif ($option eq '--verbose') {
        s/(?<=^summary: ).*$/now we are checking --verbose/;
        s/^owner:.*//;               # deleting a prop
        s/(?<=^due: ).*$/2050-01-31 19:14:09/; # adding a prop
    } elsif ($option eq '--verbose-and-all') {
        s/(?<=^summary: ).*$/now we are checking --verbose --all-props/;
        s/^due.*//;              # deleting a prop
        s/(?<=^owner: ).*$/$ENV{EMAIL}/; # adding a prop
    }
    print;

    if ( /^=== add new ticket comment below ===$/ &&
        $template =~ eval($valid_template) ) {
        print "template ok!\n";
    } elsif ( /^=== add new ticket comment below ===$/ ) {
        print "template not ok!\n";
        # print DEBUG $template;
        # print DEBUG2 eval($valid_template);
    }
}
