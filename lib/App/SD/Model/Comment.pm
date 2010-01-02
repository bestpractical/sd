package App::SD::Model::Comment;
use Any::Moose;
extends 'App::SD::Record';

use constant collection_class => 'App::SD::Collection::Comment';
has '+type' => ( default => 'comment');


sub _default_summary_format { '%s,$uuid | %s,content'}

sub declared_props { return ('content', shift->SUPER::declared_props(@_)) }

sub canonicalize_props {
    my $self = shift;
    my $props = shift;
    $self->SUPER::canonicalize_props($props);

    unless ($props->{content}) {
        delete $props->{$_} for keys %$props;
    }
}


#has SVK::Model::Ticket;

__PACKAGE__->register_reference( ticket => 'App::SD::Model::Ticket');

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
