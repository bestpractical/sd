package App::SD::Collection::Attachment;
use Any::Moose;
extends 'Prophet::Collection';

use constant record_class => 'App::SD::Model::Attachment';

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
