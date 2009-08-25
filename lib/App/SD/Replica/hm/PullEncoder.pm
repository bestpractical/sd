package App::SD::Replica::hm::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';
use Params::Validate qw(:all);
use Memoize;

has sync_source => (
    isa => 'App::SD::Replica::hm',
    is  => 'rw',
);

sub ticket_id {
    my $self   = shift;
    my $ticket = shift;
    return $ticket->{id};
}

sub ticket_last_modified {
    my $self   = shift;
    my $ticket = shift;
    return App::SD::Util::string_to_datetime( $ticket->{modified_at} );
}

sub transcode_one_txn {
    my ( $self, $txn_wrapper, $previous_state, $ticket_final ) = (@_);

    my $txn = $txn_wrapper->{object};

    my @changesets;

    my $changeset = Prophet::ChangeSet->new(
        {   original_source_uuid => $self->sync_source->uuid,
            original_sequence_no => $txn->{'id'},
        }
    );

    my $method = 'recode_' . $txn->{type};
    unless ( $self->can($method) ) {
        die "Unknown change type $txn->{type}.";
    }

    my $change = $self->$method( task => $ticket_final, transaction => $txn );

    $changeset->add_change( { change => $change } );
    for my $email ( @{ $txn->{email_entries} } ) {
        if ( my $sub = $self->can( '_recode_email_' . 'blah' ) ) {
            $sub->(
                $self,
                previous_state => $previous_state,
                email          => $email,
                txn            => $txn,
                changeset      => $changeset,
            );
        }
    }

    $self->translate_props($changeset);
    return $changeset;
}

sub find_matching_tickets {
    my $self = shift;
    my %args = ();

    if ( my $props = $self->sync_source->props ) {
        while ( my ( $k, $v ) = each %$props ) { $args{$k} = $v }
    }

    unless ( keys %args ) {
        %args = (
            owner        => 'me',
            group        => 0,
            requestor    => 'me',
            not_complete => 1,
        );
    }

    my $status = $self->sync_source->hm->act( 'TaskSearch', %args );
    unless ( $status->{'success'} ) {
        die "couldn't search";
    }
    return $status->{content}{tasks};
}

# hiveminder transaction ~= prophet changeset
# hiveminder taskhistory ~= prophet change
# hiveminder taskemail ~= prophet change
#
sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, starting_transaction => 1 } );

    my $txns = $self->sync_source->hm->search( 'TaskTransaction', task_id => $args{ticket}->{id} )
        || [];
    my @matched;
    for my $txn (@$txns) {

        # Skip things we know we don't want
        next if $txn->{'id'} < $args{'starting_transaction'};

        # Skip things we've pushed
        next if $self->sync_source->foreign_transaction_originated_locally( $txn->{'id'}, $args{ticket}->{id} );

    $txn->{history_entries}
            = $self->sync_source->hm->search( 'TaskHistory', transaction_id => $txn->{'id'} );
        $txn->{email_entries}
            = $self->sync_source->hm->search( 'TaskEmail', transaction_id => $txn->{'id'} );
        push @matched,
            {
            timestamp => App::SD::Util::string_to_datetime( $txn->{modified_at} ),
            serial    => $txn->{id},
            object    => $txn
            };
    }
    return \@matched;

}

sub add_prop_change {
    my $self = shift;
    my %args = validate( @_, { history_entry => 1, previous_state => 1, change => 1 } );


    my $field = $args{'history_entry'}{'field'} ||'';
    my $old   = $args{'history_entry'}{'old_value'} ||'';
    my $new   = $args{'history_entry'}{'new_value'} ||'';

    if ( $args{'previous_state'}->{$field} eq $new ) {
        $args{'previous_state'}->{$field} = $old;
    } else {
        $args{'previous_state'}->{$field} = $old;
        warn "$field: ". $args{'previous_state'}->{$field} . " != " . $new . "\n\n";
    }

    $args{change}->add_prop_change( name => $field, old => $old, new => $new );
}

sub recode_create {
    my $self = shift;
    my %args = validate( @_, { task => 1, transaction => 1 } );

    my $source = $self->sync_source;
    my $res    = Prophet::Change->new(
        {   record_type => 'ticket',
            record_uuid => $source->uuid_for_remote_id( $args{'task'}->{'id'} ),
            change_type => 'add_file'
        }
    );

    $args{'task'}{ $source->uuid . '-' . $_ } = delete $args{'task'}->{$_}
        for qw(id record_locator);

    while ( my ( $k, $v ) = each %{ $args{'task'} } ) {
        $res->add_prop_change( { name => $k, old => undef, new => $v } );
    }
    return $res;
}

sub recode_update {
    my $self = shift;
    my %args = validate( @_, { task => 1, transaction => 1 } );

    # In Hiveminder, a changeset has only one change
    my $res = Prophet::Change->new(
        {   record_type => 'ticket',
            record_uuid => $self->sync_source->uuid_for_remote_id( $args{'task'}->{'id'} ),
            change_type => 'update_file'
        }
    );

    for my $entry ( @{ $args{'transaction'}->{'history_entries'} } ) {
        $self->add_prop_change(
            change         => $res,
            history_entry  => $entry,
            previous_state => $args{'task'},
        );
    }
    return $res;
}

sub translate_props {
    my $self      = shift;
    my $changeset = shift;

    my %PROP_MAP = $self->sync_source->property_map('pull');

    for my $change ( $changeset->changes ) {
        next unless $change->record_type eq 'ticket';
        my @new_props;
        for my $prop ( $change->prop_changes ) {
            $prop->name( $PROP_MAP{ lc( $prop->name ) } ) if $PROP_MAP{ lc( $prop->name ) };
            next if ( $prop->name eq '_delete' );

            if ( $prop->name =~ /^(?:reporter|owner|next_action_by)$/ ) {
                $prop->old_value( $self->sync_source->user_info( id => $prop->old_value )->{'email'} ) if ($prop->old_value);
                $prop->new_value( $self->sync_source->user_info( id => $prop->new_value )->{'email'} ) if ($prop->new_value);
            }

            if ($prop->name =~ /^(?:due|completed_at|created_at)$/) {
                $prop->old_value(App::SD::Util::string_to_datetime($prop->old_value));
                $prop->new_value(App::SD::Util::string_to_datetime($prop->new_value));

             }

            # XXX, TODO, FIXME: this doesn't work any more as id stored as SOURCE_UUID-id property
            if ( $prop->name eq 'id' ) {
                $prop->old_value( $prop->old_value . '@' . $changeset->original_source_uuid )
                    if ( $prop->old_value || '' ) =~ /^\d+$/;
                $prop->old_value( $prop->new_value . '@' . $changeset->original_source_uuid )
                    if ( $prop->new_value || '' ) =~ /^\d+$/;

            }
            push @new_props, $prop;

        }
        $change->prop_changes( \@new_props );

    }
    return $changeset;
}

sub translate_ticket_state {
    my $self = shift;

    my $props = shift;

    my $translated = {%$props};
    $translated->{status} = (delete $translated->{complete})  ? 'closed' : 'open';

    return $props, $translated;

}
__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
