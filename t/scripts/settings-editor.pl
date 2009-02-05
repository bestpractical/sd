#!perl -i
use strict;
use warnings;
use lib 't/scripts';
use SDTestsEditor;

# perl script to trick Proc::InvokeEditor with for the settings command

my %tmpl_files = ( '--first' => 'sd-settings-first.tmpl',
                   '--second' => 'sd-settings-second.tmpl',
                 );

SDTestsEditor::edit( tmpl_files => { '--first' => 'sd-settings-first.tmpl',
                   '--second' => 'sd-settings-second.tmpl',
               },
    edit_callback => sub {
        my %args = @_;
        my $option = $args{option};

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
    },
    verify_callback => sub {
        my %args = @_;

        my $ok = 1;

        my %seen;     # lookup table
        my @vonly;    # answer

        # build lookup table
        @seen{@{$args{template}}} = ( );

        for my $line (@{$args{valid_template}}) {
            push(@vonly, $line) unless exists $seen{$line};
        }

        # if anything is only in the valid template, we don't match
        $ok = 0 if scalar @vonly;

        open STATUSFILE, '>', $args{status_file};
        $ok ? print STATUSFILE "ok!" : print STATUSFILE "not ok!";
        close STATUSFILE;
    }
);
