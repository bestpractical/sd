package App::SD::CLI::Command::Attachment::Content;
use Moose;
extends 'Prophet::CLI::Command::Show';
with 'App::SD::CLI::Model::Attachment';
with 'App::SD::CLI::Command';

sub run {
    my $self = shift;
    my $record =  $self->_get_record_class;
    $record->load(uuid => $self->cli->uuid);
    print $record->prop('content');
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

