package App::SD::CLI::Command::Merge;
use Moose;
extends qw/Prophet::CLI::Command::Merge/;
with 'App::SD::CLI::Command';

__PACKAGE__->meta->make_immutable;
no Moose;

1;

