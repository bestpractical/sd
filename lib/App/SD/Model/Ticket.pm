package App::SD::Model::Ticket;
use Any::Moose;
extends 'App::SD::Record';

use Term::ANSIColor;
use App::SD::Util;

use constant collection_class => 'App::SD::Collection::Ticket';
has type => ( default => 'ticket');

our $ACTIVE_STATUSES;

__PACKAGE__->register_reference( comments => 'App::SD::Collection::Comment', by => 'ticket');
__PACKAGE__->register_reference( attachments => 'App::SD::Collection::Attachment', by => 'ticket');

sub BUILD {
    my $self = shift;
    $ACTIVE_STATUSES ||= $self->app_handle->setting(label => 'active_statuses')->get();
}

sub default_prop_component { 
    my $self = shift; 
    return $self->app_handle->setting(label => 'default_component')->get()->[0];
}

sub default_prop_milestone { 
    my $self = shift; 
    return $self->app_handle->setting(label => 'default_milestone')->get()->[0];
}

=head2 default_prop_status

Returns a string of the default value of the C<status> prop.

=cut

sub default_prop_status { 
    my $self = shift; 
    return $self->app_handle->setting(label => 'default_status')->get()->[0];
}

sub has_active_status {
    my $self = shift;
    return 1 if grep { $_ eq $self->prop('status') } @{$ACTIVE_STATUSES};
}

=head2 default_prop_reporter

Returns a string of the default value of the C<reporter> prop.
(Currently, this is the config variable C<email_address> or
the environmental variable C<EMAIL>.)

=cut

sub default_prop_reporter {
    my $self = shift;
    my $reporter = $self->app_handle->current_user_email;
    if ( $reporter ) {
        return $reporter;
    }
    else {
        die "Cannot determine an email to attribute your changes to."
           ." You can\nfix this by setting the config variable"
           ." 'user.email-address'.\n";
    }
}

=head2 canonicalize_prop_status

resolved is called closed.

=cut

my %canonicalize_status = (
    resolved => 'closed',
);

sub canonicalize_prop_status {
    my $self = shift;
    my %args = @_;

    my $props = $args{props};

    if (defined $canonicalize_status{ $props->{status} }) {
        $props->{status} = $canonicalize_status{ $props->{status} };
    }

    return 1;
}


sub canonicalize_prop_due {
    my $self = shift;
    my %args = @_;
    my $props = $args{props};
    # skip blank
    return 1 unless $props->{due};
    #skip well formed
    return 1 if $props->{due} =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/; 
    require DateTime::Format::Natural;
    my $parser = DateTime::Format::Natural->new;
    my $dt = $parser->parse_datetime($props->{due});
    if ($parser->success) {
     # operate on $dt/@dt, for example:
        $props->{due} = sprintf( "%04d-%02d-%02d %02d:%02d:%02d", $dt->year, $dt->month, $dt->day, $dt->hour, $dt->min, $dt->sec);
    }
    return 1;
}


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
    my ( $self, %args ) = @_;
    return $self->validate_prop_from_recommended_values( 'status', \%args );
}

sub validate_prop_component {
    my ( $self, %args ) = @_;
    return $self->validate_prop_from_recommended_values( 'component', \%args );
}

sub validate_prop_milestone {
    my ( $self, %args ) = @_;
    return $self->validate_prop_from_recommended_values( 'milestone', \%args );
}

sub _recommended_values_for_prop_milestone {
   return @{ shift->app_handle->setting( label => 'milestones' )->get() };
}

sub _recommended_values_for_prop_status {
   return @{ shift->app_handle->setting( label => 'statuses' )->get() };
}

sub _recommended_values_for_prop_component {
   return @{ shift->app_handle->setting( label => 'components' )->get() };
}

=head2 props_to_show { 'verbose' => 1, update => 0 }

A list of which properties to display for the C<show> command (in order
from first to last).

If called with 'verbose' as a true value, will return all the
declared props of a ticket rather than the predefined list of ones
to show. (Should not be called this way during a ticket create as
new tickets have no declared properties.)

If called with 'update' as a true value, props in the prop ordering
setting will still be returned in the list even if the record
doesn't have that property. (Because we often want to not show
blank properties, but still have the option of adding them in
an update.)

=cut

sub props_to_show {
    my $self = shift;
    my $args = shift || {};
    my @props_from_config = split(',',
        ($self->app_handle->config->get( key => 'ticket.common-props') || ''));
    my $props_list = @props_from_config ? \@props_from_config :
        $self->app_handle->setting(label => 'common_ticket_props')->get();

    return @{$props_list} unless $args->{'verbose'};

    return _create_prop_ordering( hash_to_order => $self->get_props,
                                  order => $props_list,
                                  update => $args->{update});
}

=head2 _create_prop_ordering hash_to_order => $hashref, order => $arrayref [, update => 1 ]

Given references to a hash and an array, return an array of the keys of the
hash in the order specified by the array, with any extra keys at the end of the
ordering.

If called with update as a true value, will add keys in the ordering to the
returned order even if they're not in the hash.

=cut

sub _create_prop_ordering {
    my %args = @_;
    my %props = %{$args{hash_to_order}};
    my @order = @{$args{order}};
    my @new_props_list;

    # if props in the ordering are in the hash, add them to
    # the new ordering
    for my $prop (@order) {
        if ( $props{$prop} || $prop eq 'id' || $args{update} ) {
            push @new_props_list, $prop;
            delete $props{$prop};
        }
    }
    # add hash keys not in the ordering to the end of the new ordering
    push @new_props_list, keys %props;

    return @new_props_list;
}

=head2 immutable_props

A pattern of props not to show in an editor (when creating or updating a
ticket, for example). Could also be used to determine which props shouldn't be
user-modifiable.

=cut

sub immutable_props { qw(id creator created original_replica) }

=head2 is_overdue [$date]

Takes an ISO date (or uses the C<date> prop value if no date is given).

Returns false if the date is not a valid ISO date or its due date is
in the future. Returns true if the due date has passed.

=cut

sub is_overdue {
    my $self = shift;
    my $date = shift || $self->prop('due');

    my $then = App::SD::Util::string_to_datetime($date);

    if (!$then) {
        warn "Unknown date format '$date'";
        return 0;
    }

    if ($then < DateTime->now()){ 
        return 1;
    }

    return 0;
}


__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
