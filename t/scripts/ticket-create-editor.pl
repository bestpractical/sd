#!/usr/bin/perl -i
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

while (<>) {
     $template .= $_;

     s/(?<=^summary: ).*$/we are testing sd ticket create/;
     print;

    if ( /^=== add new ticket comment below ===$/ &&
        $template eq $valid_template ) {
        print "template ok!\n";
    } elsif ( /^=== add new ticket comment below ===$/ ) {
        print "template not ok!\n";
    }
}
