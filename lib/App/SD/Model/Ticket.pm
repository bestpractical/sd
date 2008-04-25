use warnings;
use strict;

package App::SD::Model::Ticket;
use base qw/App::SD::Record/;

use constant collection_class => 'App::SD::Collection::Ticket';
use constant record_type => 'ticket';


use constant summary_format => '%u %s %s';
use constant summary_props => qw(summary status);




sub validate_prop_status {
    my ($self, %args) = @_;


    # XXX: validater not called when a value is unset, so can't do
    # mandatory check here
    return 1 if scalar grep { $args{props}{status} eq $_ } qw(new open closed stalled);

    $args{errors}{status} = "'".$args{props}->{status}."' is not a valid status";
    return 0;

}

__PACKAGE__->register_reference( comments => 'App::SD::Collection::Comment',
                                 by => 'ticket'
                               );

1;
