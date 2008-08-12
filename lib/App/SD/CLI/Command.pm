package App::SD::CLI::Command;
use Moose::Role;
use Path::Class;

sub get_content {
    my $self = shift;
    my $type = shift;

    my $content;
    if (my $file = file(delete $self->args->{'file'})) {
        $content = $file->slurp();
        $self->args->{'name'} = $file->basename;
    } elsif ($content = delete $self->args->{'content'}) {

    } elsif (exists $self->args->{'edit'}) {
        $content = $self->edit_text('');
    } else {
        print "Please type your $type and press ctrl-d.\n";
        $content = do { local $/; <> };
    }

    chomp $content;
    return $content;
}

no Moose::Role;

1;

