package App::SD::CLI::Command::Attachment::Create;
use Any::Moose;
extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::Attachment';
with 'App::SD::CLI::Command';

before run => sub {
    my $self = shift;

    my $content = $self->get_content(type => 'attachment');

    die "Aborted.\n"
        if length($content) == 0;

    $self->set_prop(content => $content);
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

