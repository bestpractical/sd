package SDTestsEditor;
use strict;
use warnings;

use Prophet::Util;
use Params::Validate;
use File::Spec;

=head2 edit( tmpl_files => $tmpl_files, edit_callback => sub {}, verify_callback => sub {} )

Expects @ARGV to contain at least an option and a file to be edited. It
can also contain a replica uuid, a ticket uuid, and a status file. The last
item must always be the file to be edited. The others, if they appear, must
be in that order after the option. The status file must contain the
string 'status' in its filename.

edit_callback is called on each line of the file being edited. It should make
any edits to the lines it receives and then print what it wants to be saved to
the file.

verify_callback is called after editing is done. If you need to write
whether the template was correct to a status file, for example, this
should be done here.

=cut

sub edit {
    my %args = @_;
    validate( @_, { edit_callback => 1,
                    verify_callback => 1,
                    tmpl_files  => 1,
                   }
             );

    my $option = shift @ARGV;
    my $tmpl_file = $args{tmpl_files}->{$option};

    chomp ( my @valid_template =
        Prophet::Util->slurp("t/data/$tmpl_file") );

    my $status_file = $ARGV[-2] =~ /status/ ? delete $ARGV[-2] : undef;
    # a bit of a hack to dermine whether the last arg is a filename
    my $replica_uuid = File::Spec->file_name_is_absolute($ARGV[0]) ? undef : shift @ARGV;
    my $ticket_uuid = File::Spec->file_name_is_absolute($ARGV[0]) ? undef : shift @ARGV;

    my @template = ();
    while (<>) {
        chomp( my $line = $_ );
        push @template, $line;

        $args{edit_callback}( option => $option, template => \@template,
            valid_template => \@valid_template,
            replica_uuid => $replica_uuid,
            ticket_uuid => $ticket_uuid );
    }

    $args{verify_callback}( template => \@template,
        valid_template => \@valid_template, status_file => $status_file );
}

=head2 check_template_by_line($template, $valid_template, $errors)

$template is a reference to an array containing the template to check,
split into lines. $valid_template is the same for the template to
check against. Lines in these arrays should not have trailing newlines.
$errors is a reference to an array where error messages will be stored.

Lines in $valid_template should consist of either plain strings, or strings
beginning with 'qr/' (to delimit a regexp object).

Returns true if the templates match and false otherwise.

=cut

sub check_template_by_line {
    my @template = @{ shift @_ };
    my @valid_template = @{ shift @_ };
    my $replica_uuid = shift;
    my $ticket_uuid = shift;
    my $errors = shift;

    for my $valid_line (@valid_template) {
        my $line = shift @template;

        push @$errors, "got nothing, expected [$valid_line]" if !defined($line);

        push @$errors, "[$line] doesn't match [$valid_line]"
            if ($valid_line =~ /^qr\//) ? $line !~ eval($valid_line)
            : $line eq $valid_line;
    }

    return !(@$errors == 0);
}

1;
