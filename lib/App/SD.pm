package App::SD;
use Moose;

extends 'Prophet::App';
our $VERSION = '0.01';

__PACKAGE__->meta->make_immutable;
no Moose;
1;
