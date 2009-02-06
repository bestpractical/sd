package App::SD::Replica::trac::PullEncoder;
use Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

use Params::Validate qw(:all);
use Memoize;
use Time::Progress;

has sync_source => (
    isa => 'App::SD::Replica::trac',
    is  => 'rw'
);

sub run {
    my $self = shift;
    my %args = validate(
        @_,
        {   after    => 1,
            callback => 1,
        }
    );

    my $first_rev = ( $args{'after'} + 1 ) || 1;

    my $tickets = {};
    my @transactions;

    my @tickets = @{ $self->find_matching_tickets() };
    $self->sync_source->log("No tickets found.") if @tickets == 0;

    my $counter = 0;
    $self->sync_source->log("Discovering ticket history");
    my $progress = Time::Progress->new();
    $progress->attr( max => $#tickets );
    local $| = 1;

    for my $ticket (@tickets) {
        $counter++;
        print $progress->report( "%30b %p Est: %E\r", $counter );
        $self->sync_source->log(
            "Fetching ticket @{[$ticket->id]} - $counter of " . scalar @tickets );

        $tickets->{ $ticket->id } = $ticket;
    }

    my @changesets;

    foreach my $ticket ( values %$tickets ) {
        my $ticket_data = $self->_translate_final_ticket_state($ticket);

        #my $ticket_initial_data = $self->build_initial_ticket_state($ticket_data, $ticket);
        my $ticket_initial_data = {%$ticket_data};
        my $txns                = $self->skip_previously_seen_transactions(
            ticket       => $ticket,
            transactions => $ticket->history->entries
        );

        # Walk transactions newest to oldest.
        for my $txn ( sort { $b->date <=> $a->date } @$txns ) {
            $self->sync_source->log( $ticket->id . " - Transcoding transaction  @{[$txn->date]} " );
            my $changeset = $self->transcode_one_txn( $txn, $ticket_initial_data );
            $changeset->created( $txn->date->ymd . " " . $txn->date->hms );
            next unless $changeset->has_changes;

            # the changeset is older than the one that came before it, so it goes first
            unshift @changesets, $changeset;
            $counter++;
        }

        # create is oldest of all
        unshift @changesets, $self->build_create_changeset( $ticket_initial_data, $ticket );
    }

    my $cs_counter = 1;
    for my $changeset (@changesets) {
        $changeset->original_sequence_no( $cs_counter++ );
        $self->sync_source->log( "Applying changeset "
                . $changeset->original_sequence_no . " of "
                . scalar @changesets );
        $args{callback}->($changeset);
    }
}

sub _translate_final_ticket_state {
    my $self          = shift;
    my $ticket_object = shift;

    my $ticket_data = {

        $self->sync_source->uuid . '-id' => $ticket_object->id,

        owner => ( $ticket_object->owner || '' ),
        created     => ( $ticket_object->created->ymd . " " . $ticket_object->created->hms ),
        reporter    => ( $ticket_object->reporter || '' ),
        status      => $self->translate_status( $ticket_object->status ),
        summary     => ( $ticket_object->summary || '' ),
        description => ( $ticket_object->description || '' ),
        tags        => ( $ticket_object->keywords || '' ),
        component   => ( $ticket_object->component || '' ),
        milestone   => ( $ticket_object->milestone || '' ),
        priority    => ( $ticket_object->priority || '' ),
        severity    => ( $ticket_object->severity || '' ),
        cc          => ( $ticket_object->cc || '' ),
    };

    # delete undefined and empty fields
    delete $ticket_data->{$_}
        for grep !defined $ticket_data->{$_} || $ticket_data->{$_} eq '', keys %$ticket_data;

    return $ticket_data;
}

=head2 find_matching_tickets QUERY

Returns a Trac::TicketSearch collection for all tickets found matching your QUERY hash.

=cut

sub find_matching_tickets {
    my $self  = shift;
    my %query = (@_);
    my $search
        = Net::Trac::TicketSearch->new( connection => $self->sync_source->trac, limit => 10 );
    $search->query(%query);
    return $search->results;
}

=head2 skip_previously_seen_transactions { ticket => $id, starting_transaction => $num, transactions => \@txns  }

Returns a reference to an array of all transactions (as hashes) on ticket $id after transaction $num.

=cut

sub skip_previously_seen_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, transactions => 1 } );
    my @txns;

    for my $txn ( sort @{ $args{transactions} } ) {

        # Skip things we know we've already pulled
        #next if $txn < $args{'starting_transaction'};

        # Skip things we've pushed
        #next if $self->sync_source->foreign_transaction_originated_locally($txn, $args{'ticket'});
        push @txns, $txn;
    }
    return \@txns;
}

sub build_initial_ticket_state {
    my $self          = shift;
    my $final_state   = shift;
    my $ticket_object = shift;

    my %initial_state = %{$final_state};

    for my $txn ( reverse @{ $ticket_object->history->entries } ) {
        for my $pc ( values %{ $txn->prop_changes } ) {
            unless ( $initial_state{ $pc->property } eq $pc->new_value ) {
                warn "I was expecting "
                    . $pc->property
                    . " to be "
                    . $pc->new_value
                    . " but it was actually "
                    . $initial_state{ $pc->property };
            }
            $initial_state{ $pc->property } = $pc->old_value;

        }
    }
    return \%initial_state;
}

sub build_create_changeset {
    my $self        = shift;
    my $create_data = shift;
    my $ticket      = shift;
    warn "My ticket id is " . $ticket->id;
    my $changeset = Prophet::ChangeSet->new(
        {   original_source_uuid => $self->sync_source->uuid_for_remote_id( $ticket->id ),

            #original_sequence_no => 1, # XXX TODO THIS IS JNOT A VALID SEQUENCE NUMBER
            creator => $self->resolve_user_id_to( email_address => $ticket->reporter ),
        }
    );

    my $change = Prophet::Change->new(
        {   record_type => 'ticket',
            record_uuid => $self->sync_source->uuid_for_remote_id( $ticket->id ),
            change_type => 'add_file'
        }
    );

    for my $prop ( keys %$create_data ) {
        next unless defined $create_data->{$prop};
        $change->add_prop_change( name => $prop, old => '', new => $create_data->{$prop} );
    }

    $changeset->add_change( { change => $change } );
    return $changeset;
}

sub transcode_one_txn {
    my ( $self, $txn, $ticket, $txn_number ) = (@_);
    my $changeset = Prophet::ChangeSet->new(
        {   original_source_uuid => $self->sync_source->uuid_for_remote_id(
                $ticket->{ $self->sync_source->uuid . '-id' }
            ),

         #        original_sequence_no => $txn_number, #XXX TODO THIS IS NOT A VALID SEQUENCE NUMBER
            creator => $self->resolve_user_id_to( email_address => $txn->author ),
        }
    );

    my $change = Prophet::Change->new(
        {   record_type => 'ticket',
            record_uuid => $self->sync_source->uuid_for_remote_id(
                $ticket->{ $self->sync_source->uuid . '-id' }
            ),
            change_type => 'update_file'
        }
    );

    foreach my $prop_change ( values %{ $txn->prop_changes || {} } ) {
        my $new      = $prop_change->new_value;
        my $old      = $prop_change->old_value;
        my $property = $prop_change->property;

        $old = undef if ( $old eq '' );
        $new = undef if ( $new eq '' );

        # walk back $ticket's state
        if (   ( !defined $new && !defined $ticket->{$property} )
            || ( defined $new && defined $ticket->{$property} && $ticket->{$property} eq $new ) )
        {
            $ticket->{$property} = $old;
        }

        $change->add_prop_change( name => $property, old => $old, new => $new );

    }

    $changeset->add_change( { change => $change } ) if $change->has_prop_changes;

    my $comment = Prophet::Change->new(
        {   record_type => 'comment',
            record_uuid => Data::UUID->new->create_str(),
            change_type => 'add_file'
        });

    my $content = $txn->content;

    $comment->add_prop_change( name => 'created', new  => $txn->date->ymd. ' ' .$txn->date->hms);
    $comment->add_prop_change( name => 'creator', new  => $self->resolve_user_id_to( email_address => $txn->author) );
    $comment->add_prop_change( name => 'content', new => $content );
    $comment->add_prop_change( name => 'content_type', new => 'text/html' );
    $comment->add_prop_change(
        name => 'ticket',
        new => $self->sync_source->uuid_for_remote_id( $ticket->{ $self->sync_source->uuid . '-id' } )
    );

    $changeset->add_change({change => $comment});
    return $changeset;
}

sub _recode_attachment_create {
    my $self   = shift;
    my %args   = validate( @_, { ticket => 1, txn => 1, changeset => 1, attachment => 1 } );
    my $change = Prophet::Change->new(
        {   record_type => 'attachment',
            record_uuid => $self->sync_source->uuid_for_url(
                $self->sync_source->remote_url . "/attachment/" . $args{'attachment'}->{'id'}
            ),
            change_type => 'add_file'
        }
    );
    $change->add_prop_change(
        name => 'content_type',
        old  => undef,
        new  => $args{'attachment'}->{'ContentType'}
    );
    $change->add_prop_change( name => 'created', old => undef, new => $args{'txn'}->{'Created'} );
    $change->add_prop_change(
        name => 'creator',
        old  => undef,
        new  => $self->resolve_user_id_to( email_address => $args{'attachment'}->{'Creator'} )
    );
    $change->add_prop_change(
        name => 'content',
        old  => undef,
        new  => $args{'attachment'}->{'Content'}
    );
    $change->add_prop_change(
        name => 'name',
        old  => undef,
        new  => $args{'attachment'}->{'Filename'}
    );
    $change->add_prop_change(
        name => 'ticket',
        old  => undef,
        new  => $self->sync_source->uuid_for_remote_id(
            $args{'ticket'}->{ $self->sync_source->uuid . '-id' }
        )
    );
    $args{'changeset'}->add_change( { change => $change } );
}

sub translate_status {
    my $self   = shift;
    my $status = shift;

    $status =~ s/^resolved$/closed/;
    return $status;
}

my %PROP_MAP;
sub translate_prop_names {
    my $self      = shift;
    my $changeset = shift;

    for my $change ( $changeset->changes ) {
        next unless $change->record_type eq 'ticket';

        my @new_props;
        for my $prop ( $change->prop_changes ) {
            next if ( ( $PROP_MAP{ lc( $prop->name ) } || '' ) eq '_delete' );
            $prop->name( $PROP_MAP{ lc( $prop->name ) } ) if $PROP_MAP{ lc( $prop->name ) };

            # Normalize away undef -> "" and vice-versa
            for (qw/new_value old_value/) {
                $prop->$_("") if !defined( $prop->$_() );
            }
            next if ( $prop->old_value eq $prop->new_value );

            if ( $prop->name =~ /^cf-(.*)$/ ) {
                $prop->name( 'custom-' . $1 );
            }

            push @new_props, $prop;

        }
        $change->prop_changes( \@new_props );

    }
    return $changeset;
}

sub resolve_user_id_to {
    my $self = shift;
    my $to   = shift;
    my $id   = shift;
    return $id . '@trac-instance.local';

}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
