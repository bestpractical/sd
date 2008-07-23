use warnings;
use strict;

package App::SD::Record; # should probably be Prophet::App::Record
use Moose;
use Params::Validate;
use DateTime;


sub declared_props { 'created', inner() }

extends 'Prophet::Record';

sub get_props {
    my $self = shift;
    my $props = $self->SUPER::get_props(@_);

    $self->set_props(props => { created => $props->{date} })
      if !$props->{created} && $props->{date};

    $self->set_props(props => {date => undef})
      if $props->{date};

    return $self->SUPER::get_props(@_);
}

sub canonicalize_prop_created {
    my $self = shift;
    my %args = validate(@_, { props => 1, errors => 1});
    my $props = shift;
    my $created =    $args{props}->{created}
                  || $args{props}->{date};
    if (!$created ) {
        my $date = DateTime->now;
        $args{props}->{created} = $date->ymd." ".$date->hms;
    }
    return 1;
}



1;
