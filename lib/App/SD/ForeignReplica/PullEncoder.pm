package App::SD::ForeignReplica::PullEncoder;
use Any::Moose;
use App::SD::Util;

sub warp_list_to_old_value {
    my $self    = shift;
    my $current = shift;
    my $add     = shift;
    my $del     = shift;
    $_ = '' foreach grep !defined, $current, $add, $del;

    my @new = grep defined && length, split /\s*,\s*/, $current;
    my @old = grep defined && length && $_ ne $add, (@new, $del);
    return join( ", ", @old );
}

=head2 _only_pull_tickets_modified_after

If we've previously pulled from this sync source, this routine will
return a datetime object. It's safe not to evaluate any ticket last
modified before that datetime

=cut

sub _only_pull_tickets_modified_after {
    my $self = shift;

    # last modified date is in GMT and searches are in user-time XXX -check assumption
    # because of this, we really want to back that date down by one day to catch overlap
    # XXX TODO we are playing FAST AND LOOSE WITH DATE MATH
    # XXX TODO THIS WILL HURT US SOME DAY
    # At that time, Jesse will buy you a beer.
    my $last_pull = $self->sync_source->upstream_last_modified_date();
    return undef unless $last_pull;
    my $before = App::SD::Util::string_to_datetime($last_pull);
    die "Failed to parse '" . $self->sync_source->upstream_last_modified_date() . "' as a timestamp"
        unless ($before);

    # 26 hours ago deals with most any possible timezone/dst edge case
    $before->subtract( hours => 26 );

    return $before;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
