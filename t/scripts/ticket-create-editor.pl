#!/usr/bin/perl -i
use strict;
use warnings;

use Prophet::Util;
use File::Spec;

# perl script to trick Proc::InvokeEditor with for the ticket create command

my $template = '';

my %tmpl_files = ( '--no-args' => 'sd-ticket-create.tmpl',
                   '--all-props' => 'sd-ticket-create.tmpl',
                   '--verbose' => 'sd-ticket-create-verbose.tmpl',
                   '--verbose-and-all' => 'sd-ticket-create-verbose.tmpl',
                 );

my $tmpl_file = $tmpl_files{shift @ARGV};

my $valid_template =
    Prophet::Util->slurp("t/data/$tmpl_file");

my $replica_uuid = shift @ARGV;

$valid_template =~ s/USER/$ENV{USER}/g;
$valid_template =~ s/REPLICA/$replica_uuid/g;
$valid_template =~ s/EMAIL/$ENV{EMAIL}/g;

# open DEBUG, '>', '/home/spang/tmp/got.txt';
# open DEBUG2, '>', '/home/spang/tmp/wanted.txt';

while (<>) {
     $template .= $_;

     s/(?<=^summary: ).*$/we are testing sd ticket create/;
     print;

    if ( /^=== add new ticket comment below ===$/ &&
        $template eq $valid_template ) {
        print "template ok!\n";
    } elsif ( /^=== add new ticket comment below ===$/ ) {
        print "template not ok!\n";
        # print DEBUG $template;
        # print DEBUG2 $valid_template;
    }
}
