package App::SD::Model::Ticket;
use Moose;
extends 'App::SD::Record';

use Term::ANSIColor;

use constant collection_class => 'App::SD::Collection::Ticket';
use constant type => 'ticket';

=head2 default_prop_status

Returns a string of the default value of the status prop.

=cut

sub default_prop_status { 'new' }

=head2 _default_summary_format

The default ticket summary format (used for displaying tickets in a
list, generally).

=cut

sub _default_summary_format { '%s,$luid | %s,summary | %s,status' }

=head2 validate_prop_status { props = $hashref, errors = $hashref }

Determines whether the status prop value given in C<$args{props}{status}>
is valid.

Returns true if the status is valid. If the status is invalid, sets
C<$args{errors}{status}> to an error message and returns false.

=cut

sub validate_prop_status {
    my ($self, %args) = @_;


    # XXX: validater not called when a value is unset, so can't do
    # mandatory check here
    return 1 if scalar grep { $args{props}{status} eq $_ } qw(new open closed stalled);

    $args{errors}{status} = "'".$args{props}->{status}."' is not a valid status";
    return 0;

}

sub color_prop_status {
    my ($self, $value) = @_;

    # these colors were picked out of a hat
    my $color = $value eq 'new'     ? 'red'
              : $value eq 'open'    ? 'yellow'
              : $value eq 'closed'  ? 'green'
              : $value eq 'stalled' ? 'blue'
                                    : '';

    return colored($value, $color);
}

sub props_to_show {
    ('id', 'summary', 'status', 'owner', 'due', 'creator', 'reported_by', 'CF-Broken in', 'CF-Severity')
}

__PACKAGE__->register_reference( comments => 'App::SD::Collection::Comment', by => 'ticket');
__PACKAGE__->register_reference( attachments => 'App::SD::Collection::Attachment', by => 'ticket');

__PACKAGE__->meta->make_immutable;
no Moose;
1;
