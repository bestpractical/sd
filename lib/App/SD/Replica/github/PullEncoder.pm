package App::SD::Replica::github::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

use Params::Validate qw(:all);
use Memoize;
use Time::Progress;
use DateTime;

has sync_source => (
    isa => 'App::SD::Replica::github',
    is  => 'rw',
);

my %PROP_MAP = %App::SD::Replica::github::PROP_MAP;

sub ticket_id {
    my $self   = shift;
    return shift->{number};
}

=head2 translate_ticket_state

=cut

sub translate_ticket_state {
    my $self   = shift;
    my $ticket = shift;

    return $ticket;
}

=head2 find_matching_tickets QUERY

Returns a array of all tickets found matching your QUERY hash.

=cut

sub find_matching_tickets {
    my $self                   = shift;
    my %query                  = (@_);
    my $last_changeset_seen_dt = $self->_only_pull_tickets_modified_after()
      || DateTime->from_epoch( epoch => 0 );
    $last_changeset_seen_dt->set_time_zone( '-0700' );
    my $dt = $last_changeset_seen_dt;
    my $last_dt_str = sprintf(
        "%4d/%02d/%02d %02d:%02d:%02d -0700",
        $dt->year, $dt->month,  $dt->day,
        $dt->hour, $dt->minute, $dt->second
    );
    my $issue = $self->sync_source->github->issue;
    my @updated =
      grep { $_->{updated_at} ge $last_dt_str }
      ( @{ $issue->list('open') }, @{ $issue->list('closed') } );
    return \@updated;
}

sub _only_pull_tickets_modified_after {
    my $self = shift;

    my $last_pull = $self->sync_source->upstream_last_modified_date();
    return unless $last_pull;
    my $before = App::SD::Util::string_to_datetime($last_pull);
    $self->log_debug( "Failed to parse '" . $self->sync_source->upstream_last_modified_date() . "' as a timestamp. That means we have to sync ALL history") unless ($before);
    return $before;
}

=head2 find_matching_transactions { ticket => $id, starting_transaction => $num  }

Returns a reference to an array of all transactions (as hashes) on ticket $id after transaction $num.

=cut

sub find_matching_transactions {
    my $self     = shift;
    my %args     = validate( @_, { ticket => 1, starting_transaction => 1 } );
    my @raw_txns =
      @{ $self->sync_source->github->issue->comments( $args{ticket}->{number} ) };

    for my $comment (@raw_txns) {
        $comment->{date} =
          App::SD::Util::string_to_datetime( $comment->{date} );
    }

    my @txns;
    for my $txn ( sort { $a->{id} <=> $b->{id} } @raw_txns ) {
        my $txn_date = $txn->{date}->epoch;

        # Skip things we know we've already pulled
        next if $txn_date < ( $args{'starting_transaction'} || 0 );

        # Skip things we've pushed
        next if (
            $self->sync_source->foreign_transaction_originated_locally(
                $txn_date, $args{'ticket'}->{number}
            )
          );

        # ok. it didn't originate locally. we might want to integrate it
        push @txns,
          {
            timestamp => $txn->{date},
            serial    => $txn->{id},
            object    => $txn,
          };
    }

    my $ticket_created =
      App::SD::Util::string_to_datetime( $args{ticket}->{created_at} );
    if ( $ticket_created->epoch >= $args{'starting_transaction'} || 0 ) {
        unshift @txns,
          {
            timestamp => $ticket_created,
            serial    => 0,
            object    => $args{ticket},
          };
    }

    $self->sync_source->log_debug('Done looking at pulled txns');

    return \@txns;
}

sub transcode_create_txn {
    my $self        = shift;
    my $txn         = shift;
    my $ticket      = $txn->{object};
    my $ticket_uuid = 
          $self->sync_source->uuid_for_remote_id($ticket->{number});
    my $creator =
      $self->resolve_user_id_to( email_address => $ticket->{user} );
    my $created = $txn->{timestamp};
    my $changeset = Prophet::ChangeSet->new(
        {
            original_source_uuid => $ticket_uuid,
            original_sequence_no => 0,
            creator              => $creator,
            created              => $created->ymd . " " . $created->hms
        }
    );

    my $change = Prophet::Change->new(
        {
            record_type => 'ticket',
            record_uuid => $ticket_uuid,
            change_type => 'add_file',
        }
    );

    for my $prop (qw/title body state/) {
        $change->add_prop_change(
            name => $PROP_MAP{$prop} || $prop,
            new => $ticket->{$prop},
        );
    }

    $change->add_prop_change(
        name => $self->sync_source->uuid . '-id',
        new => $ticket->{number},
    );

    $changeset->add_change( { change => $change } );

    return $changeset;
}

# we might get return:
# 0 changesets if it was a null txn
# 1 changeset if it was a normal txn
# 2 changesets if we needed to to some magic fixups.

sub transcode_one_txn {
    my $self               = shift;
    my $txn_wrapper        = shift;
    my $ticket = shift;

    my $txn = $txn_wrapper->{object};
    if ( $txn_wrapper->{serial} == 0 ) {
        return $self->transcode_create_txn($txn_wrapper);
    }

    my $ticket_uuid =
      $self->sync_source->uuid_for_remote_id( $ticket->{number} );

    my $changeset = Prophet::ChangeSet->new(
        {
            original_source_uuid => $ticket_uuid,
            original_sequence_no => $txn->{id},
            creator =>
              $self->resolve_user_id_to( email_address => $txn->{author} ),
            created => $txn->{date}->ymd . " " . $txn->{date}->hms
        }
    );

    $self->_include_change_comment( $changeset, $ticket_uuid, $txn );

    return unless $changeset->has_changes;
    return $changeset;
}

sub _include_change_comment {
    my $self        = shift;
    my $changeset   = shift;
    my $ticket_uuid = shift;
    my $txn         = shift;

    my $comment = $self->new_comment_creation_change();

    if ( my $content = $txn->{content} ) {
        if ( $content !~ /^\s*$/s ) {
            $comment->add_prop_change(
                name => 'created',
                new  => $txn->{date}->ymd . ' ' . $txn->{date}->hms,
            );
            $comment->add_prop_change(
                name => 'creator',
                new =>
                  $self->resolve_user_id_to( email_address => $txn->{author} ),
            );
            $comment->add_prop_change( name => 'content', new => $content );
            $comment->add_prop_change(
                name => 'content_type',
                new  => 'text/plain',
            );
            $comment->add_prop_change( name => 'ticket', new => $ticket_uuid, );

            $changeset->add_change( { change => $comment } );
        }
    }

}

sub translate_prop_status {
    my $self   = shift;
    my $status = shift;
    return lc($status);
}

sub resolve_user_id_to {
    my $self = shift;
    my $to   = shift;
    my $id   = shift;
    return $id . '@github';
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
