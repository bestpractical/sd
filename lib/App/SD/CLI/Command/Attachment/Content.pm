package App::SD::CLI::Command::Attachment::Content;
use Any::Moose;
extends 'Prophet::CLI::Command::Show';
with 'App::SD::CLI::Model::Attachment';
with 'App::SD::CLI::Command';

sub run {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    my $record =  $self->_get_record_object;
    $record->load(uuid => $self->uuid);
    print $record->prop('content');
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

