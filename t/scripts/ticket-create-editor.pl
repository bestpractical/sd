#!/usr/bin/perl -i
use strict;
use warnings;
use lib 't/scripts';
use SDTestsEditor;

# perl script to trick Proc::InvokeEditor with for the ticket create command


SDTestsEditor::edit( tmpl_files => { '--no-args' => 'sd-ticket-create.tmpl',
                   '--all-props' => 'sd-ticket-create.tmpl',
                   '--verbose' => 'sd-ticket-create-verbose.tmpl',
                   '--verbose-and-all' => 'sd-ticket-create-verbose.tmpl',
                 },
    edit_callback => sub {
        my %args = @_;

        s/(?<=^summary: ).*$/we are testing sd ticket create/;
        print;

        if ( /^=== add new ticket comment below ===$/) {
            my $errors = [];
            my $template_ok =
                SDTestsEditor::check_template_by_line($args{template},
                $args{valid_template}, $args{replica_uuid},
                $args{ticket_uuid}, $errors);
            if ($template_ok) {
                print "template ok!\n";
            } else {
                print "template not ok! errors were:\n";
                map { print $_ . "\n" } @$errors;
            }
        }

      },
    verify_callback => sub {},
  );
