#!perl -i.bak
use strict;
use warnings;
use Prophet::Test::Editor;

# perl script to trick Proc::InvokeEditor with for the ticket update command

Prophet::Test::Editor::edit(
    tmpl_files => { '--no-args' => 'sd-ticket-update.tmpl',
                   '--all-props' => 'sd-ticket-update-all-props.tmpl',
                   '--verbose' => 'sd-ticket-update-verbose.tmpl',
                   '--verbose-and-all' =>
                        'sd-ticket-update-verbose-all-props.tmpl',
               },
    edit_callback => sub {
        my %args = @_;
        my $option = $args{option};

        if ($option eq '--no-args') {
            s/(?<=^summary: ).*$/summary changed/;
            s/^owner:.*$//;               # deleting a prop
            s/(?<=^due: ).*$/2050-01-25 23:11:42/; # adding a prop
        } elsif ($option eq '--all-props') {
            s/(?<=summary: ).*$/now we are checking --all-props/;
            s/^due:.*//;              # deleting a prop
            s/(?<=^owner: ).*$/$ENV{PROPHET_EMAIL}/; # adding a prop
        } elsif ($option eq '--verbose') {
            s/(?<=^summary: ).*$/now we are checking --verbose/;
            s/^owner:.*//;               # deleting a prop
            s/(?<=^due: ).*$/2050-01-31 19:14:09/; # adding a prop
        } elsif ($option eq '--verbose-and-all') {
            s/(?<=^summary: ).*$/now we are checking --verbose --all-props/;
            s/^due.*//;              # deleting a prop
            s/(?<=^owner: ).*$/$ENV{PROPHET_EMAIL}/; # adding a prop
        }
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
