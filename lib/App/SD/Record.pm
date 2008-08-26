use warnings;
use strict;

package App::SD::Record; # should probably be Prophet::App::Record
use Moose;
use Params::Validate;


sub declared_props { 'created', inner() }

extends 'Prophet::Record';

sub canonicalize_prop_created {
    my $self = shift;
    my %args = validate(@_, { props => 1, errors => 1});

    # has the record been created yet? if so, we don't want to try to
    # get its properties
    my $props = $self->uuid ? $self->get_props : {};

    my $created = $args{props}->{created}
               || $args{props}->{date}
               || $props->{created}
               || $props->{date};

    if (!$created ) {
        my @now = gmtime();

        $args{props}->{created} = sprintf(
            "%04d-%02d-%02d %02d:%02d:%02d",
            ( $now[5] + 1900 ),
            ( $now[4] + 1 ),
            $now[3], $now[2], $now[1], $now[0]
        );

    }
    return 1;
}

__PACKAGE__->meta->make_immutable;
no Moose;


1;
