package App::SD::CLI::Command::TextEditor;
use Moose::Role;
use Params::Validate qw/validate/;

sub try_to_edit {
    my $self = shift;
    my %args = validate(
        @_,
        {   template => 1,
            record   => 1,
        }
    );

    my $record = $args{'record'};

    my $template = ${ $args{template} };

    # do the edit
    my $updated = $self->edit_text($template);

    die "Aborted.\n" if $updated eq $template;    # user didn't change anything

    $self->process_template(
        template => $args{template},
        edited   => $updated,
        record   => $record
    );
}

sub handle_template_errors {
        my $self = shift;
        my %args = validate ( @_ , { error => 1, template_ref => 1, bad_template => 1});


        $self->prompt_Yn("Want to return back to editing?") || die "Aborted.\n";

        ${ $args{'template_ref'} }
            = "=== Your template contained errors ====\n\n".$args{error}."\n\n"
            . $args{bad_template};
        return 0;
    }

no Moose::Role;
1;
