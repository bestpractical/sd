package App::SD::CLI::Command;
use Moose::Role;
use Path::Class;

sub get_content {
    my $self = shift;
    my %args = @_;

    my $content;
    if (my $file = file($self->delete_arg('file'))) {
        $content = $file->slurp();
        $self->set_prop(name => $file->basename);
    } elsif ($content = $self->delete_arg('content')) {

    } elsif ($args{default_edit} || $self->has_arg('edit')) {
        $content = $self->edit_text('');
    } else {
        print "Please type your $args{type} and press ctrl-d.\n";
        $content = do { local $/; <> };
    }

    chomp $content;
    return $content;
}

no Moose::Role;

1;

