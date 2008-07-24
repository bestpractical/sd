use warnings;
use strict;

package App::SD::Record; # should probably be Prophet::App::Record
use Moose;
use Params::Validate;
use DateTime;


sub declared_props { 'created', inner() }

extends 'Prophet::Record';

around get_props => sub {
    my ($next, $self, @args) = @_;
    my $props = $self->$next(@args);

    $self->set_props(props => { created => $props->{date} })
      if !$props->{created} && $props->{date};

    $self->set_props(props => {date => undef})
      if $props->{date};

    return $self->$next(@args);
};

sub canonicalize_prop_created {
    my $self = shift;
    my %args = validate(@_, { props => 1, errors => 1});

    my $props = $self->get_props;

    my $created = $args{props}->{created}
               || $args{props}->{date}
               || $props->{created}
               || $props->{date};

    if (!$created ) {
        my $date = DateTime->now;
        $args{props}->{created} = $date->ymd." ".$date->hms;
    }
    return 1;
}



1;
