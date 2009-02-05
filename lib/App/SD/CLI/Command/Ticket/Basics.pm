package App::SD::CLI::Command::Ticket::Basics;
use Any::Moose;
extends 'Prophet::CLI::Command::Show';
with 'App::SD::CLI::Command';
with 'App::SD::CLI::Model::Ticket';

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

