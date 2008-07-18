use warnings;
use strict;

package App::SD::Model::Comment;
use base qw/App::SD::Record/;
use Params::Validate;
use DateTime;

use constant collection_class => 'App::SD::Collection::Comment';
use constant record_type => 'comment';


sub _default_summary_format { '%s,$uuid | %s,content'}

use constant declared_props => qw(date content);


#has SVK::Model::Ticket;

__PACKAGE__->register_reference( ticket => 'App::SD::Model::Comment');

sub canonicalize_prop_date {
    my $self = shift;
    my %args = validate(@_, { props => 1, errors => 1});
    my $props = shift;
    if (!$args{props}->{date} ) {
        my $date = DateTime->now;
        $args{props}->{date} = $date->ymd." ".$date->hms;
    }
    return 1;
    
}


1;
