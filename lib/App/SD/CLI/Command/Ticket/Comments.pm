package App::SD::CLI::Command::Ticket::Comments;
use Any::Moose;

extends 'Prophet::CLI::Command::Search';
with 'Prophet::CLI::RecordCommand';
with 'App::SD::CLI::Command';
with 'App::SD::CLI::Model::Ticket';

sub run {
    my $self = shift;
    my $record = $self->_get_record_object;

    $self->require_uuid;
    $record->load( uuid => $self->uuid );

    if (@{$record->comments}) {
        for my $entry ($self->sort_by_prop( 'created' => $record->comments)) {
            print "id: ".$entry->luid." (".$entry->uuid.")\n";
            print "created: ".$entry->prop('created')."\n\n";
            print $entry->prop('content')."\n\n";
        }
    } else {
        print "No comments found\n";
    }
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

