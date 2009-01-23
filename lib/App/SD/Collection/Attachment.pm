package App::SD::Collection::Attachment;
use Moose;
extends 'Prophet::Collection';

use constant record_class => 'App::SD::Model::Attachment';

__PACKAGE__->meta->make_immutable;
no Moose;

1;
