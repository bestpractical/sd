package App::SD::ForeignReplica::PullEncoder;
use Any::Moose;
use App::SD::Util;
use Params::Validate qw/validate/;

sub run {
    my $self = shift;
    my %args = validate( @_, {   after    => 1, callback => 1, });

    $self->sync_source->log('Finding matching tickets');
    
    my $tickets = $self->find_matching_tickets( query => $self->sync_source->query );

    if ( scalar @$tickets == 0 ) {
        $self->sync_source->log("No tickets found.");
        return;
    }

    my $counter = 0;
    $self->sync_source->log("Discovering ticket history");

    my ( $last_txn, @changesets );
    my $previously_modified = App::SD::Util::string_to_datetime( $self->sync_source->upstream_last_modified_date );

    my $progress = Time::Progress->new();
    $progress->attr( max => $#$tickets );

    local $| = 1;
    
    my $last_modified;

    for my $ticket (@$tickets) {
        $counter++;

        my $ticket_id = $ticket->{id};

        print $progress->report( "%30b %p Est: %E\r", $counter );
        $self->sync_source->log( "Fetching ticket $ticket_id - $counter of " . scalar @$tickets );

        my $final_state         = $self->_translate_final_ticket_state($ticket);
        my $initial_state       = {%$final_state};

        my $transactions = $self->find_matching_transactions(
            ticket => $ticket,
            starting_transaction =>
                $self->sync_source->app_handle->handle->last_changeset_from_source(
                $self->sync_source->uuid_for_remote_id($ticket_id)
                ) || 1
        );

        # Walk transactions newest to oldest.
        my $txn_counter = 0;
        for my $txn ( sort { $b->{'serial'} <=> $a->{'serial'} } @$transactions ) {
            my $created =  App::SD::Util::string_to_datetime( $txn->{timesta} );

            $last_modified = $txn->{timestamp}     if ( !$last_modified || ( $txn->{timestamp} > $last_modified ) );

            $txn_counter++;
            $self->sync_source->log( "$ticket_id Transcoding transaction $txn_counter of " . scalar @$transactions );
            my $changeset = $self->transcode_one_txn( $txn, $initial_state, $final_state );
            next unless $changeset && $changeset->has_changes;
            # the changesets are older than the ones that came before, so they goes first
            unshift @changesets, $changeset;
        }
    }

    my $cs_counter = 0;
    for (@changesets) {
        $self->sync_source->log(
            "Applying changeset " . ++$cs_counter . " of " . scalar @changesets );
        $args{callback}->($_);
    }

    $self->sync_source->record_upstream_last_modified_date($last_modified)
        if ( ( $last_modified ? $last_modified->epoch : 0 )
        > ( $previously_modified ? $previously_modified->epoch : 0 ) );

}


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
