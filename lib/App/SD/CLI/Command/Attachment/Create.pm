package App::SD::CLI::Command::Attachment::Create;
use Moose;
extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::Attachment';
with 'App::SD::CLI::Command';

before run => sub {
    my $self = shift;
    $self->set_prop(content => $self->get_content(type => 'attachment'));
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

