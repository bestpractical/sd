package App::SD::CLI::Command::Ticket::Comments;
use Moose;
extends 'Prophet::CLI::Command';
with 'Prophet::CLI::RecordCommand';
with 'App::SD::CLI::Model::Ticket';

sub run {
    my $self = shift;
    my $record = $self->_get_record_class();

    $self->require_uuid;
    $record->load( uuid => $self->uuid );
    unless (@{$record->comments}) {
        print "No comments found\n";
    }

    for my $entry (sort { $a->prop('created') cmp $b->prop('created') } @{$record->comments}) {
         print "id: ".$entry->luid." (".$entry->uuid.")\n";
        print "created: ".$entry->prop('created')."\n";
        print $entry->prop('content')."\n";
    }

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

