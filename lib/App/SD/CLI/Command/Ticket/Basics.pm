package App::SD::CLI::Command::Ticket::Basics;
use Moose;
extends 'Prophet::CLI::Command::Show';
with 'App::SD::CLI::Command';
with 'App::SD::CLI::Model::Ticket';

__PACKAGE__->meta->make_immutable;
no Moose;

1;

