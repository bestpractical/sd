package App::SD::Model::Ticket;
use Moose;
extends 'App::SD::Record';

use Term::ANSIColor;

use constant collection_class => 'App::SD::Collection::Ticket';
use constant type => 'ticket';

sub default_prop_status { 'new' }

sub _default_summary_format { '%s,$luid | %s,summary | %s,status' }

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

sub color_prop_due {
    my ($self, $due) = @_;

    return colored($due, 'red') if $self->is_overdue($due);
    return $due;
}

sub props_to_show {
    ('id', 'summary', 'status', 'owner', 'created', 'due', 'creator', 'reported_by', 'CF-Broken in', 'CF-Severity')
}

# this expects ISO dates. we should improve it in the future to require
sub is_overdue {
    my $self = shift;
    my $date = shift || $self->prop('due');

    return 0 if !$date;

    if ($date !~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/) {
        warn "Unknown date format '$date'";
        return 0;
    }

    my $dt = eval { DateTime->new(
            year      => $1,
            month     => $2,
            day       => $3,
            hour      => $4,
            minute    => $5,
            second    => $6,
            time_zone => 'UTC',
    ) };
    warn $@ if $@;
    return 0 if !$dt;

    my $now = DateTime->now(time_zone => 'UTC');
    return $now > $dt;
}

__PACKAGE__->register_reference( comments => 'App::SD::Collection::Comment', by => 'ticket');
__PACKAGE__->register_reference( attachments => 'App::SD::Collection::Attachment', by => 'ticket');

__PACKAGE__->meta->make_immutable;
no Moose;
1;
