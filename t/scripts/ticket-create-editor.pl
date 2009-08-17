#!perl -i.bak
use strict;
use warnings;
use Prophet::Test::Editor;

# perl script to trick Proc::InvokeEditor with for the ticket create command


Prophet::Test::Editor::edit(
    tmpl_files => { '--no-args' => 'sd-ticket-create.tmpl',
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
                Prophet::Test::Editor::check_template_by_line($args{template},
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
