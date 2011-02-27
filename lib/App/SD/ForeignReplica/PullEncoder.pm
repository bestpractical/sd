package App::SD::ForeignReplica::PullEncoder;
use Any::Moose;
use App::SD::Util;
use Params::Validate qw/validate/;

with 'Prophet::CLI::ProgressBar';

sub run {
    my $self = shift;
    my %args = validate( @_, { after => 1});

    $self->sync_source->log('Finding matching tickets');
    my $tickets = $self->find_matching_tickets( query => $self->sync_source->query );

    if ( @$tickets == 0 ) {
        $self->sync_source->log("No tickets found.");
        return;
    }

    my $counter = 0;
    $self->sync_source->log_debug("Discovering ticket history");

    my ( $last_modified, $last_txn, @changesets );

    my $progress = $self->progress_bar(
        max => $#$tickets,
        format => "Fetching ticket history %30b %p Est: %E\r",
    );

    for my $ticket (@$tickets) {
        $counter++;
        my $changesets;
        $progress->();
        $self->sync_source->log_debug( "Fetching $counter of " . scalar @$tickets  . " tickets");
        ( $last_modified, $changesets ) = $self->transcode_ticket( $ticket, $last_modified );
        unshift @changesets, @$changesets;
    }
    my $sorted_changesets = [ sort {
        $a->original_sequence_no <=> $b->original_sequence_no } @changesets ];
    return $sorted_changesets;
}

sub ticket_last_modified { undef}

sub transcode_ticket {
    my $self          = shift;
    my $ticket        = shift;
    my $last_modified = shift;
    my @changesets;

    if ( my $ticket_last_modified = $self->ticket_last_modified($ticket) ) {

        $last_modified = $ticket_last_modified if ( !$last_modified || $ticket_last_modified > $last_modified );
    }

    my $transactions = $self->find_matching_transactions(
        ticket               => $ticket,
        starting_transaction => $self->sync_source->app_handle->handle->last_changeset_from_source(
            $self->sync_source->uuid_for_remote_id( $self->ticket_id($ticket) )
            ) || 1
    );

    my $changesets;
    ( $last_modified, $changesets ) = $self->transcode_history( $ticket, $transactions, $last_modified );
    return ( $last_modified, $changesets );
}


sub transcode_history {
    my $self          = shift;
    my $ticket        = shift;
    my $transactions  = shift;
    my $last_modified = shift;
    my $ticket_id     = $self->ticket_id($ticket);

    my @changesets;

    # Walk transactions newest to oldest.
    my $txn_counter         = 0;
    my ($initial_state, $final_state)          = $self->translate_ticket_state($ticket, $transactions);


    for my $txn ( sort { $b->{'serial'} <=> $a->{'serial'} } @$transactions ) {
        $last_modified = $txn->{timestamp} if ( !$last_modified || ( $txn->{timestamp} > $last_modified ) );
        $self->sync_source->log_debug( "$ticket_id Transcoding transaction " . ++$txn_counter . " of " . scalar @$transactions );

        my $changeset = $self->transcode_one_txn( $txn, $initial_state, $final_state );
        next unless $changeset && $changeset->has_changes;

        # the changesets are older than the ones that came before, so they go
        # first
        unshift @changesets, $changeset;
    }
    return ( $last_modified, \@changesets );
}


sub translate_ticket_state {
    die 'translate_ticket_state must be implemented';
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

sub new_comment_creation_change {
	my $self = shift;
	return Prophet::Change->new(
        {
            record_type => 'comment',
            record_uuid =>  $self->sync_source->uuid_generator->create_str()
            ,    # comments are never edited, we can have a random uuid
            change_type => 'add_file'
        }
    );
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
