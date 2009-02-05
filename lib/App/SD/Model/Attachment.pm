package App::SD::Model::Attachment;
use Any::Moose;
extends 'App::SD::Record';
use Params::Validate qw/validate/;

use constant collection_class => 'App::SD::Collection::Attachment';
has type => ( default => 'attachment');


sub _default_summary_format { '%s,$luid | %s,name | %s,content_type'}

__PACKAGE__->register_reference( ticket => 'App::SD::Model::Ticket');

sub create {
    my $self = shift;
    my %args = validate( @_,  {props => 1});


    return (0,"You can't create an attachment without specifying a 'ticket' uuid") unless ($args{'props'}->{'ticket'});

    $args{'props'}->{'content_type'} ||=  'text/plain'; # XXX TODO use real mime typing;
    

    $self->SUPER::create(%args);
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
