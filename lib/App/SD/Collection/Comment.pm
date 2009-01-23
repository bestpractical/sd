package App::SD::Collection::Comment;
use Moose;
extends 'Prophet::Collection';

use constant record_class => 'App::SD::Model::Comment';

__PACKAGE__->meta->make_immutable;
no Moose;

1;

