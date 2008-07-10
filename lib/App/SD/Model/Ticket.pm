package App::SD::Model::Ticket;
use Moose;
extends 'App::SD::Record';

use Term::ANSIColor;

use constant collection_class => 'App::SD::Collection::Ticket';
use constant record_type => 'ticket';

sub summary_props {
    #my @data = split(/\s+/, shift->handle->config('ticket_summary_props') || 'status summary');
    my @data = split(/\s+/, 'summary status');
    return @data;

}
sub summary_format {
    #return shift->handle->config('ticket_summary_format')|| '%l %-7.7s %-60.60s';
            return '%l %s %s';
}


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

1;
