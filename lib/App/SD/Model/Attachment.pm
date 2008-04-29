use warnings;
use strict;

package App::SD::Model::Attachment;
use base qw/App::SD::Record/;

use constant collection_class => 'App::SD::Collection::Attachment';
use constant record_type => 'attachment';

use constant summary_format => '%u %s';
use constant summary_props => qw(filename);

__PACKAGE__->register_reference( ticket => 'App::SD::Model::Ticket');

1;
