package App::SD::Model::Ticket;
use Moose;
extends 'App::SD::Record';

use Term::ANSIColor;
use HTTP::Date;

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

=head2 color_prop_status $value

Returns the stats prop value C<$value> wrapped in colorization escape
codes (from L<Term::ANSIColor>).

=cut

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

=head2 color_prop_due $due

Returns the due prop value C<$due> wrapped in colorization escape
codes if it is overdue.

=cut

sub color_prop_due {
    my ($self, $due) = @_;

    return colored($due, 'red') if $self->is_overdue($due);
    return $due;
}

=head2 props_to_show

A list of which properties to display for the C<show> command (in order
from first to last).

=cut

sub props_to_show {
    ('id', 'summary', 'status', 'owner', 'created', 'due', 'creator', 'reported_by')
}

=head2 props_not_to_edit

A pattern of props not to show in an editor (when creating or updating a
ticket, for example). Could also be used to determine which props shouldn't be
user-modifiable.

=cut

sub props_not_to_edit { qr/^(id|created|creator)$/ }

=head2 is_overdue [$date]

Takes an ISO date (or uses the C<date> prop value if no date is given).

Returns false if the date is not a valid ISO date or its due date is
in the future. Returns true if the due date has passed.

=cut

# this expects ISO dates. we should improve it in the future to require
sub is_overdue {
    my $self = shift;
    my $date = shift || $self->prop('due');

    return 0 if !$date;

    if ($date !~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
        warn "Unknown date format '$date'";
        return 0;
    }

    my $then = HTTP::Date::str2time($date, 'GMT');
    return 0 if !$then;

    my $now = time();
    return $now > $then;
}

__PACKAGE__->register_reference( comments => 'App::SD::Collection::Comment', by => 'ticket');
__PACKAGE__->register_reference( attachments => 'App::SD::Collection::Attachment', by => 'ticket');

__PACKAGE__->meta->make_immutable;
no Moose;
1;
