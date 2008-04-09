use warnings;
use strict;

package App::SD::Model::Comment;
use base qw/App::SD::Record/;

use constant collection_class => 'App::SD::Collection::Comment';
use constant record_type => 'comment';

use constant summary_format => '%u %s';
use constant summary_props => qw(content);

#has SVK::Model::Ticket;

__PACKAGE__->register_reference( ticket => 'App::SD::Model::Comment');

1;
