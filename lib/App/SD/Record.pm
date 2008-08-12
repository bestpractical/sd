use warnings;
use strict;

package App::SD::Record; # should probably be Prophet::App::Record
use Moose;
use Params::Validate;
use DateTime;


sub declared_props { 'date', inner() }

extends 'Prophet::Record';

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
