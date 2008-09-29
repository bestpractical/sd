package App::SD::Model::Comment;
use Moose;
extends 'App::SD::Record';

use constant collection_class => 'App::SD::Collection::Comment';
use constant type => 'comment';


sub _default_summary_format { '%s,$uuid | %s,content'}

augment declared_props => sub {'content'};


#has SVK::Model::Ticket;

__PACKAGE__->register_reference( ticket => 'App::SD::Model::Ticket');

__PACKAGE__->meta->make_immutable;
no Moose;
1;
