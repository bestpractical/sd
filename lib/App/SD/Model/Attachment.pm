use warnings;
use strict;

package App::SD::Model::Attachment;
use base qw/App::SD::Record/;
use Params::Validate qw/validate/;

use constant collection_class => 'App::SD::Collection::Attachment';
use constant record_type => 'attachment';

use constant summary_format => '%u %s';
use constant summary_props => qw(name content_type);

__PACKAGE__->register_reference( ticket => 'App::SD::Model::Ticket');

sub create {
    my $self = shift;
    my %args = validate( @_,  {props => 1});


    return (0,"You can't create an attachment without specifying a 'ticket' uuid") unless ($args{'props'}->{'ticket'});

    $args{'props'}->{'content_type'} ||=  'text/plain'; # XXX TODO use real mime typing;
    

    $self->SUPER::create(%args);
}



1;
