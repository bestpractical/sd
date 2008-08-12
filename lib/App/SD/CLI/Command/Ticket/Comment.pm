package App::SD::CLI::Command::Ticket::Comment;
use Moose;
extends 'App::SD::CLI::Command::Ticket::Comment::Create';

sub type { 'comment' }

__PACKAGE__->meta->make_immutable;
no Moose;

1;

