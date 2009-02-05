package App::SD::Record; 
use Any::Moose;
use Params::Validate;

extends 'Prophet::Record';


sub declared_props { 'created' }

sub canonicalize_prop_created {
    my $self = shift;
    my %args = validate(@_, { props => 1, errors => 1});

    # has the record been created yet? if not, we don't want to try to
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
no Any::Moose;


1;
