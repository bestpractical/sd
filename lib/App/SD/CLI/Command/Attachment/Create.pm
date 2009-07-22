package App::SD::CLI::Command::Attachment::Create;
use Any::Moose;
extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::Attachment';
with 'App::SD::CLI::Command';

sub run {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    my $content = $self->get_content(type => 'attachment');

    die "Aborted.\n"
        if length($content) == 0;

    $self->set_prop(content => $content);
    $self->SUPER::run(@_);
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

