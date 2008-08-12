package App::SD::CLI::Command::Ticket::Comments;
use Moose;
extends 'Prophet::CLI::Command';
with 'Prophet::CLI::RecordCommand';
with 'App::SD::CLI::Model::Ticket';

sub run {
    my $self = shift;
    my $record = $self->_get_record_class();
    $record->load( uuid => $self->uuid );
    unless (@{$record->comments}) {
        print "No comments found\n";
    }

    for my $entry (sort { $a->prop('date') cmp $b->prop('date') } @{$record->comments}) {
         print "id: ".$entry->luid." (".$entry->uuid.")\n";
        print "date: ".$entry->prop('date')."\n";
        print $entry->prop('content')."\n";
    }

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

