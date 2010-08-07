package App::SD::Replica::debbugs::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

use Params::Validate qw(:all);
use Memoize;
use Mail::Address qw();

use Prophet::ChangeSet;
use Prophet::Change;

use DateTime;

has sync_source => (
    isa => 'App::SD::Replica::debbugs',
    is => 'rw',
);

my $DEBUG = 1;

# methods used in RUN

=head2 ticket_last_modified $ticket

Given a ticket, returns when it was last modified
as a unix epoch.

=cut

# used in transcode_ticket, which is called from RUN
sub ticket_last_modified {
    my ($self, $ticket) = @_;

    return $ticket->{last_modified};
}

=head2 ticket_id $ticket

Given a ticket, returns its ID from the foreign source. In the case of Debbugs,
this is the bug's bug number.

=cut

sub ticket_id {
    my ($self, $ticket) = @_;

    return $ticket->{id};
}

=head2 find_matching_tickets( query => QUERY )

Looks up ticket numbers matching the query and returns an arrayref listing
their statuses.

This method is called from App::SD::ForeignReplica::PullEncoder's run method,
and is the first method called there.

=cut

sub find_matching_tickets {
    my $self = shift;
    my %args = @_;

    if ( $DEBUG ) {
        print "* query is:\n";
        use Data::Dump qw(pp);
        pp $args{query};
    }

    # XXX TODO: sanity-check the query (don't try to send anything to debbugs
    # that it doesn't understand)

    # an arrayref of bug numbers
    my $bug_numbers;

    if ( $args{query}->{bugnumber} ) {
        $bug_numbers = [ $args{query}->{bugnumber} ];
    }
    else {
        $bug_numbers
            = $self->sync_source->debbugs->get_bugs( %{ $args{query} } )->result();
    }

    if ( $DEBUG ) {
        print "* matching bug numbers:\n";
        pp $bug_numbers;
    }

    # we also need to get the bug statuses, because we'll need some more
    # information in the ticket objects than just the bug numbers, for
    # the API that SD gives us
    my $bug_statuses = $self->sync_source->debbugs->get_status(
        @{ $bug_numbers } )->result();

    # it's OK to throw away the keys because the hashes for each bug
    # still have the bug number in them (under the key 'id')
    my @bug_statuses = values %{ $bug_statuses };

    return wantarray ? @bug_statuses : \@bug_statuses;
}

=head2 find_matching_transactions { ticket => $id, starting_transaction => $num  }

Returns a reference to an array of all transactions (as hashes) on ticket $id
after transaction $num.

XXX this method assumes that the foreign source has GLOBAL SEQUENCE NUMBER.
How do we work around this?

=cut

sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, starting_transaction => 1 } );

    if ( $DEBUG ) {
        warn "* find_matching_transactions\n";
    }

    # get_machine_readable_bug_log guarantees returned transactions to
    # be in order from oldest to newest
    my @raw_txns
        = @{ $self->sync_source->debbugs->get_machine_readable_bug_log(
            $self->ticket_id( $args{ticket} ))->result() };

    my @txns;
    # XXX this is mostly copy-pasted from the trac sync
    for my $txn ( @raw_txns ) {
        my $txn_id = $txn->{log_entry_num};

        # we need to use the datetime representation an awful
        # lot, so might as well only create it once, here
        $txn->{date} = DateTime->from_epoch( epoch => $txn->{time} );

        # Skip things we know we've already pulled
        next if $txn_id < ( $args{'starting_transaction'} || 0 );
        # Skip things we've pushed
        next if ($self->sync_source->foreign_transaction_originated_locally(
                $txn_id, $self->ticket_id( $args{'ticket'} )));

        # ok. it didn't originate locally. we might want to integrate it
        # XXX what is the difference between timestamp and serial?
        push @txns, { timestamp => $txn->{time},
                      serial => $txn_id,
                      object => $txn};
    }
    $self->sync_source->log_debug('Done looking at pulled txns');

    return \@txns;
}

=head2 translate_ticket_state

XXX wtf is this supposed to do?

=cut

sub translate_ticket_state {
    my $self          = shift;
    my $ticket_object = shift;
    my $transactions = shift;

    if ( $DEBUG ) {
        warn "* translate_ticket_state\n";
    }

    my $created = DateTime->from_epoch( epoch => $ticket_object->{date} );

    my $ticket_data = {

        $self->sync_source->uuid . '-id' => $self->ticket_id( $ticket_object ),

        status      => $self->_determine_bug_status( $ticket_object ),
        created     => ( $created->ymd . " " . $created->hms ),

        owner       => ( $ticket_object->{owner} || undef ),
        reporter    => ( $ticket_object->{originator} || undef ),
        title       => ( $ticket_object->{subject} || undef ),
        tags        => ( $ticket_object->{tags} || undef ),
        package     => ( $ticket_object->{package} || undef ),
        severity    => ( $ticket_object->{severity} || undef ),
        id          => ( $ticket_object->{id} || undef ),
    };

    # $ticket will be updated as we walk backwards through log entries.
    # Eventually, $ticket should be the beginning state of the ticket
    # (just after create).
    return ($ticket_data, $ticket_data);
}

=head2 transcode_one_txn $txn_wrapper, $ticket, $ticket_final

Turn a single transaction into a Prophet ChangeSet. May
return zero or one changesets (some transactions aren't
worth creating changesets for).

=cut

# XXX mostly stolen from the trac replica
sub transcode_one_txn {
    my ( $self, $txn_wrapper, $ticket, $ticket_final ) = (@_);

    if ( $DEBUG ) {
        warn "* transcode_one_txn\n";
    }

    my $txn = $txn_wrapper->{object};

    # for now we're not recording outgoing messages locally; most
    # of them are boring (and one is always present before the actual
    # incoming message that creates the bug, which is a slight
    # complexity that we'd prefer to ignore for now.

    return if ( $txn->{type} eq 'outgoing-message' );

    # XXX testing
    # if ( $DEBUG ) {
    #     unless ( $txn->{type} eq 'create' ) {
    #         warn "- skipping txn with type $txn->{type}\n";
    #         return;
    #     }
    # }

    # my $ticket_uuid = $self->sync_source->uuid_for_remote_id(
    #     $ticket->{ $self->sync_source->uuid . '-id' } );
    my $ticket_uuid = $self->sync_source->uuid_for_remote_id( $ticket->{id} );

    my %transcode_dispatch = (
        'create'           => \&_transcode_create_txn,
        'close'            => \&_transcode_close_txn,
        'change'           => \&_transcode_change_txn,
        'incoming-message' => \&_transcode_comment_txn,
    );

    my $sub = $transcode_dispatch{ $txn->{type} };

    if ( $sub ) {
        warn "- dispatching to $txn->{type}\n";
        return $sub->( $self, $txn, $ticket, $ticket_final, $ticket_uuid );
    }
    else {
        die "Attempt to transcode unknown log entry type '$txn->{type}'.".
            "Please update debbugs bridge for changed API!\n";
    }
}

=head2 database_settings

Custom settings for this foreign replica.

=cut

sub database_settings {
    my $self = shift;

    my @resolutions = qw(closed wontfix);

    my @active_statuses = qw(open pending stalled);

    return {
        active_statuses => [@active_statuses],
        statuses => [ @active_statuses, @resolutions ],
    };
}

=head1 INTERNAL FUNCTIONS

This stuff isn't required by the SD foreign replica API; they're merely used
internally to this module and called by things that are implementing part of
the interface.

=cut

sub _determine_bug_status {
    my ($self, $ticket_obj) = @_;

    if ( $ticket_obj->{archived} ) {
        return 'archived';
    }
    elsif ( $ticket_obj->{fixed} ) {
        return 'closed';
    }
    elsif ( $ticket_obj->{blockedby} ) {
        return 'stalled';
    }
    elsif ( $ticket_obj->{pending} eq 'pending-fixed' ) {
        return 'pending';
    }
    else {
        return 'open';
    }
}

sub _transcode_create_txn {
    my ($self, $txn, $ticket, $ticket_final, $ticket_uuid) = @_;

    # use Data::Dump qw(pp);
    # warn pp $txn;

    my $changeset = $self->_create_changeset(
        $txn, $ticket_uuid,
        $self->resolve_user_id_to_email( $txn->{submitter} ),
    );

    my $change = Prophet::Change->new(
        {   record_type => 'ticket',
            record_uuid => $ticket_uuid,
            change_type => 'add_file'
        }
    );

    for my $prop ( qw(package severity version) ) {
        $change->add_prop_change(
            name => $prop,
            old => '',
            new => $txn->{pseudo_headers}->{$prop},
        );
    }

    $change->add_prop_change(
        name => 'summary',
        old => '',
        new => $txn->{title},
    );

    $change->add_prop_change(
        name => 'reporter',
        old => '',
        new => $txn->{submitter},
    );

    $change->add_prop_change(
        name => 'status',
        old => '',
        new => 'open',
    );

    $change->add_prop_change(
        name => 'debian-id',
        old => '',
        new => $ticket->{id},
    );

    $changeset->add_change( { change => $change } );

    # creates basically always have comments too
    my $comment = $self->_create_new_comment( $txn, $ticket_uuid,
        $self->resolve_user_id_to_email( $txn->{submitter} ) );

    if ( $comment ) {
        $changeset->add_change( { change => $comment } );
    }

    return $changeset;
}

sub _create_changeset {
    my ($self, $txn, $ticket_uuid, $creator) = @_;

    my $changeset = Prophet::ChangeSet->new(
        {   original_source_uuid => $ticket_uuid,
            original_sequence_no => $txn->{log_entry_num},
            creator => $creator,
            created => $txn->{date}->ymd . " " . $txn->{date}->hms
        }
    );

    return $changeset;
}

sub _transcode_comment_txn {
    my ($self, $txn, $ticket, $ticket_final, $ticket_uuid) = @_;

    my %to_hash = map { $_ => 1 } @{ $txn->{to} };

    # don't record control messages; their data should be recorded
    # elsewhere
    return if $to_hash{'control@bugs.debian.org'};

    my $changeset = $self->_create_changeset(
        $txn, $ticket_uuid,
        $self->resolve_user_id_to_email( $txn->{from} ),
    );

    my $comment = $self->_create_new_comment( $txn, $ticket_uuid,
        $self->resolve_user_id_to_email( $txn->{from} ) );

    if ( $comment ) {
        $changeset->add_change( { change => $comment } );
        return $changeset;
    }
}

=head2 _create_new_comment $txn, $ticket_uuid

Given a transaction and a ticket UUID, creates a new comment based on the email
body. May return undef if the message was blank.

=cut

sub _create_new_comment {
    my ($self, $txn, $ticket_uuid, $creator) = @_;

    my $message = $txn->{body};
    my $comment = $self->new_comment_creation_change();

    if ( $message !~ /^\s*$/s ) {
        $comment->add_prop_change(
            name => 'created',
            new => $txn->{date}->ymd . ' ' . $txn->{date}->hms,
        );
        $comment->add_prop_change(
            name => 'creator',
            new => $creator,
        );
        $comment->add_prop_change( name => 'content', new => $message );
        $comment->add_prop_change(
            name => 'content_type',
            new => 'text/plain',
        );
        $comment->add_prop_change( name => 'ticket', new => $ticket_uuid );

        return $comment;
    }
}

sub _transcode_close_txn {
    my ($self, $txn, $ticket, $ticket_final, $ticket_uuid) = @_;

    my $changeset = $self->_create_changeset(
        $txn, $ticket_uuid,
        $self->resolve_user_id_to_email( $txn->{from} ),
    );

    my $change = Prophet::Change->new(
        {   record_type => 'ticket',
            record_uuid => $ticket_uuid,
            change_type => 'update_file'
        }
    );

    $change->add_prop_change(
        name => 'status',
        # XXX how to determine the previous state of this bug? we
        # don't really know it
        old => 'unknown',
        new => 'closed',
    );
    $ticket->{status} = 'closed';

    # mails to nnnnnn-close@ always contain a comment too, but
    # there's also the BTS close command -- this stuff should
    # be abstracted away by the server-side code in the SOAP call
    my $comment = $self->_create_new_comment( $txn, $ticket_uuid,
        $self->resolve_user_id_to_email( $txn->{from} ) );

    if ( $comment ) {
        $changeset->add_change( { change => $comment } );
    }

    return $changeset;
}

sub _transcode_change_txn {
    my ($self, $txn, $ticket, $ticket_final, $ticket_uuid) = @_;

    # changes from old bugs that don't record metadata in the log are ignored
    # for now, because they're a pain to parse (and if you go back far enough,
    # nothing at all is actually recorded)
    if ( $txn->{command} ) {
        my $changeset = $self->_create_changeset(
            $txn, $ticket_uuid,
            $self->resolve_user_id_to_email( $txn->{requester} ),
        );

        my $change = Prophet::Change->new(
            {   record_type => 'ticket',
                record_uuid => $ticket_uuid,
                change_type => 'update_file'
            }
        );

        # it turns out we probably want to do different things
        # for each available command
        my %transcode_change_dispatch = (
            'tag'           => \&_transcode_tag_change,
            'package'       => \&_transcode_package_change,
            'submitter'     => \&_transcode_submitter_change,
        );

        my $sub = $transcode_change_dispatch{ $txn->{command} };

        if ( $sub ) {
            warn "- dispatching to $txn->{command}\n";
            $sub->( $self, $txn, $ticket, $ticket_final, $change);
        }
        else {
            use Data::Dump qw(pp);
            pp $txn;
            die "Attempt to transcode unknown change command ".
                "'$txn->{command}'. Please update debbugs bridge for ".
                "changed API!\n";
        }

        # for my $prop ( keys %{ $txn->{old_data} } ) {
        #     $prop = lc $prop;
        #     $change->add_prop_change(
        #         # XXX are we doing any translation between debbugs and SD
        #         # with %PROP_MAP?
        #         name => $prop,
        #         old  => $txn->{old_data}->{$prop},
        #         new  => $txn->{new_data}->{$prop},
        #     );
        # }

        $changeset->add_change( { change => $change } )
            if $change->has_prop_changes;

        return $changeset->has_changes ? $changeset : undef;
    }
}

sub _transcode_tag_change {
    my ($self, $txn, $ticket, $ticket_final, $change) = @_;

    my %old_keywords = map { $_ => 1 }
        split( / /, $txn->{old_data}->{keywords} );
    my %new_keywords = map { $_ => 1 }
        split( / /, $txn->{new_data}->{keywords} );

    my (%additions, %subtractions);
    for my $new_keyword ( keys %new_keywords ) {
        $additions{ $new_keyword } = 1 unless $old_keywords{ $new_keyword };
    }
    for my $old_keyword ( keys %old_keywords ) {
        $subtractions{ $old_keyword } = 1 unless $new_keywords{ $old_keyword };
    }

    # sometimes we need to do special things based on keywords, e.g.
    # for 'pending', which affects status, not keywords
    if ( $additions{pending} ) {
        $change->add_prop_change(
            name => 'status',
            # XXX how to determine previous status?
            old  => 'unknown',
            new  => 'pending',
        );
        $ticket->{status} = 'pending';
        delete $new_keywords{pending};
    }
    elsif ( $subtractions{pending} ) {
        my $old_status = $ticket->{status};
        $ticket->{status} = 'pending';
        $change->add_prop_change(
            name => 'status',
            old  => $old_status,
            new  => $self->_determine_bug_status( $ticket ),
        );
        delete $old_keywords{pending};
    }

    # pending can change at the same time as other keyword
    # additions / subtractions, so add those too if they exist
    if ( keys %old_keywords || keys %new_keywords ) {
        $change->add_prop_change(
            name => 'tags',
            old  => join( ' ', sort keys %old_keywords ),
            new  => join( ' ', sort keys %new_keywords ),
        );
        $ticket->{tags} = join( ' ', sort keys %new_keywords );
    }
}

# this happens when a bug is reassigned to a different package
sub _transcode_package_change {
    my ($self, $txn, $ticket, $ticket_final, $change) = @_;

    $change->add_prop_change(
        name => 'package',
        old => $txn->{old_data}->{package},
        new => $txn->{new_data}->{package},
    );
    $ticket->{package} = $txn->{new_data}->{package};
}

sub _transcode_submitter_change {
    my ($self, $txn, $ticket, $ticket_final, $change) = @_;

    $change->add_prop_change(
        name => 'reporter',
        old => $txn->{old_data}->{originator},
        new => $txn->{new_data}->{originator},
    );
    $ticket->{reporter} = $txn->{old_data}->{originator};
}

# our %PROP_MAP = (
#     package                 => 'component',
#     originator              => 'reporter',
#     # remote_prop => 'sd_prop',
# );

# =head2 translate_prop_names L<Prophet::ChangeSet>

# =cut

# sub translate_prop_names {
#     my $self      = shift;
#     my $changeset = shift;

#     # ...

#     return $changeset;
# }

=head2 resolve_user_id_to_email ID

Transform a remote user id to an email address. In the case of
debbugs, we just parse the full address and return only the
address part, for now.

=cut

sub resolve_user_id_to_email {
    my $self = shift;
    my $id   = shift;

    my @addrs = Mail::Address->parse( $id );

    # we'll throw away the name for now
    return $addrs[0]->address;
}

memoize 'resolve_user_id_to_email';

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
