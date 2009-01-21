package App::SD::Replica::trac::PullEncoder;
use Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

use Params::Validate qw(:all);
use Memoize;
use Time::Progress;

has sync_source => 
    ( isa => 'App::SD::Replica::trac',
      is => 'rw');

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

    my @tickets =  $self->find_matching_tickets();

    $self->sync_source->log("No tickets found.") if @tickets == 0;

    my $counter = 0;
    $self->sync_source->log("Discovering ticket history");
    my $progress = Time::Progress->new();
    $progress->attr( max => $#tickets );
    local $| = 1;
    for my $id (@tickets) {
        $counter++;
        print $progress->report( "%30b %p Est: %E\r", $counter );

        $self->sync_source->log( "Fetching ticket $id - $counter of " . scalar @tickets);
        $tickets->{ $id } = $self->_translate_final_ticket_state(
            $self->sync_source->trac->show( type => 'ticket', id => $id )
        );
        push @transactions, @{
            $self->find_matching_transactions(
                ticket               => $id,
                starting_transaction => $first_rev
            )
        };
    }

    my $txn_counter = 0;
    my @changesets;
    for my $txn ( sort { $b->{'id'} <=> $a->{'id'} } @transactions ) {
        $txn_counter++;
        $self->sync_source->log("Transcoding transaction  @{[$txn->{'id'}]} - $txn_counter of ". scalar @transactions);
        my $changeset = $self->transcode_one_txn( $txn, $tickets->{ $txn->{Ticket} } );
        $changeset->created( $txn->{'Created'} );
        next unless $changeset->has_changes;
        unshift @changesets, $changeset;
    }

    my $cs_counter = 0;
    for ( @changesets ) {
        $self->sync_source->log("Applying changeset ".++$cs_counter . " of ".scalar @changesets); 
        $args{callback}->($_)
    }
}

sub _translate_final_ticket_state {
    my $self   = shift;
    my $ticket = shift;

    # undefine empty fields, we'll delete after cleaning
    $ticket->{$_} = undef for
        grep defined $ticket->{$_} && $ticket->{$_} eq '',
        keys %$ticket;

    $ticket->{'id'} =~ s/^ticket\///g;

    $ticket->{ $self->sync_source->uuid . '-' . lc($_) } = delete $ticket->{$_}
        for qw(Queue id);

    delete $ticket->{'Owner'} if lc($ticket->{'Owner'}) eq 'nobody';
    $ticket->{'Owner'} = $self->resolve_user_id_to( email_address => $ticket->{'Owner'} )
        if $ticket->{'Owner'};

    # normalize names of watchers to variant with suffix 's'
    foreach my $field (qw(Requestor Cc AdminCc)) {
        if ( defined $ticket->{$field} && defined $ticket->{$field .'s'} ) {
            die "It's impossible! Ticket has '$field' and '${field}s'";
        } elsif ( defined $ticket->{$field} ) {
            $ticket->{$field .'s'} = delete $ticket->{$field};
        }
    }

    $ticket->{$_} = $self->unix_time_to_iso( $ticket->{$_} )
        for grep defined $ticket->{$_}, qw(Created Resolved Told LastUpdated Due Starts Started);

    $ticket->{$_} =~ s/ minutes$//
        for grep defined $ticket->{$_}, qw(TimeWorked TimeLeft TimeEstimated);

    $ticket->{'Status'} =~ $self->translate_status($ticket->{'Status'});

    # delete undefined and empty fields
    delete $ticket->{$_} for
        grep !defined $ticket->{$_} || $ticket->{$_} eq '',
        keys %$ticket;

    return $ticket;
}

=head2 find_matching_tickets QUERY

Returns a Trac::TicketSearch collection for all tickets found matching your QUERY hash.

=cut

sub find_matching_tickets {
    my $self   = shift;
    my %query  = (@_);
    my $search = Net::Trac::TicketSearch->new( connection => $self->sync_source->trac );

    $search->query(%query);

    print $_->id, "\n" for @{ $search->results };

    return $search->results;
}

=head2 find_matching_transactions { ticket => $id, starting_transaction => $num }

Returns a reference to an array of all transactions (as hashes) on ticket $id after transaction $num.

=cut

sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, starting_transaction => 1 } );
    my @txns;

    my $trac_handle = $self->sync_source->trac;

     my @transactions =  $rt_handle->get_transaction_ids( parent_id => $args{'ticket'} );
    for my $txn ( sort @transactions) {
        # Skip things we know we've already pulled
        next if $txn < $args{'starting_transaction'}; 
        
        # Skip things we've pushed
        next if $self->sync_source->foreign_transaction_originated_locally($txn, $args{'ticket'});


        my $txn_hash = $rt_handle->get_transaction(
            parent_id => $args{'ticket'},
            id        => $txn,
            type      => 'ticket'
        );
        if ( my $attachments = delete $txn_hash->{'Attachments'} ) {
            for my $attach ( split( /\n/, $attachments ) ) {
                next unless ( $attach =~ /^(\d+):/ );
                my $id = $1;
                my $a  = $rt_handle->get_attachment( parent_id => $args{'ticket'}, id        => $id);

                push( @{ $txn_hash->{_attachments} }, $a )
                    if ( $a->{Filename} );

            }

        }
        push @txns, $txn_hash;
    }
    return \@txns;
}

sub transcode_one_txn {
    my ( $self, $txn, $ticket ) = (@_);

    my $sub = $self->can( '_recode_txn_' . $txn->{'Type'} );
    unless ($sub) {
        die "Transaction type $txn->{Type} (for transaction $txn->{id}) not implemented yet";
    }

    my $changeset = Prophet::ChangeSet->new(
        {   original_source_uuid => $self->sync_source->uuid,
            original_sequence_no => $txn->{'id'},
            creator              => $self->resolve_user_id_to( email_address => $txn->{'Creator'} ),
        }
    );

    if (   $txn->{'Ticket'} ne $ticket->{ $self->sync_source->uuid . '-id' }
        && $txn->{'Type'} !~ /^(?:Comment|Correspond)$/ )
    {
        warn "Skipping a data change from a merged ticket"
            . $txn->{'Ticket'} . ' vs '
            . $ticket->{ $self->sync_source->uuid . '-id' };
        next;
    }

    delete $txn->{'OldValue'} if ( $txn->{'OldValue'} eq '' );
    delete $txn->{'NewValue'} if ( $txn->{'NewValue'} eq '' );

    $sub->( $self, ticket => $ticket, txn => $txn, changeset => $changeset );
    $self->translate_prop_names($changeset);

    if ( my $attachments = delete $txn->{'_attachments'} ) {
        for my $attach (@$attachments) {
            $self->_recode_attachment_create(
                ticket     => $ticket,
                txn        => $txn,
                changeset  => $changeset,
                attachment => $attach
            );
        }
    }

    return $changeset;
}

sub _recode_attachment_create {
    my $self   = shift;
    my %args   = validate( @_, { ticket => 1, txn => 1, changeset => 1, attachment => 1 } );
    my $change = Prophet::Change->new(
        {   record_type => 'attachment',
            record_uuid => $self->sync_source->uuid_for_url( $self->sync_source->remote_url . "/attachment/" . $args{'attachment'}->{'id'} ),
            change_type => 'add_file'
        }
    );
    $change->add_prop_change( name => 'content_type', old  => undef, new  => $args{'attachment'}->{'ContentType'});
    $change->add_prop_change( name => 'created', old  => undef, new  => $args{'txn'}->{'Created'} );
    $change->add_prop_change( name => 'creator', old  => undef, new  => $self->resolve_user_id_to( email_address => $args{'attachment'}->{'Creator'}));
    $change->add_prop_change( name => 'content', old  => undef, new  => $args{'attachment'}->{'Content'});
    $change->add_prop_change( name => 'name', old  => undef, new  => $args{'attachment'}->{'Filename'});
    $change->add_prop_change( name => 'ticket', old  => undef, new  => $self->sync_source->uuid_for_remote_id( $args{'ticket'}->{ $self->sync_source->uuid . '-id'} ));
    $args{'changeset'}->add_change( { change => $change } );
}

use HTTP::Date;

sub unix_time_to_iso {
    my $self = shift;
    my $date = shift;

    return undef if $date eq 'Not set';
    return HTTP::Date::time2iso($date);
}

our %PROP_MAP = (
    subject         => 'summary',
    status          => 'status',
    owner           => 'owner',
    initialpriority => '_delete',
    finalpriority   => '_delete',
    told            => '_delete',
    requestor       => 'reporter',
    requestors      => 'reporter',
    cc              => 'cc',
    ccs             => 'cc',
    admincc         => 'admin_cc',
    adminccs        => 'admin_cc',
    refersto        => 'refers_to',
    referredtoby    => 'referred_to_by',
    dependson       => 'depends_on',
    dependedonby    => 'depended_on_by',
    hasmember       => 'members',
    memberof        => 'member_of',
    priority        => 'priority_integer',
    resolved        => 'completed',
    due             => 'due',
    creator         => 'creator',
    timeworked      => 'time_worked',
    timeleft        => 'time_left',
    timeestimated   => 'time_estimated',
    lastupdated     => '_delete',
    created         => 'created',
    queue           => 'queue',
    starts          => '_delete',
    started         => '_delete',
);

sub translate_status {
    my $self = shift;
    my $status = shift;

    $status =~ s/^resolved$/closed/;
    

    return $status;
}

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
                $prop->$_("") if !defined ($prop->$_());
                }
            next if ( $prop->old_value eq $prop->new_value);

            if ( $prop->name =~ /^cf-(.*)$/ ) {
                $prop->name( 'custom-' . $1 );
            }

            push @new_props, $prop;

        }
        $change->prop_changes( \@new_props );

    }
    return $changeset;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
