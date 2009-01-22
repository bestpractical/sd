package App::SD::Collection::Ticket;
use Moose;
extends 'Prophet::Collection';

use constant record_class => 'App::SD::Model::Ticket';

__PACKAGE__->meta->make_immutable;
no Moose;

1;

