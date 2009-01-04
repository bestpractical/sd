package App::SD::Replica::hm::PullEncoder;
use Moose;
use Params::Validate qw(:all);
use Memoize;

has sync_source => (
    isa => 'App::SD::Replica::hm',
    is => 'rw',
);


sub run {
    my $self = shift;
    my %args = validate(@_,
        {   after    => 1,
            callback => 1,
            });
    my $first_rev = ( $args{'after'} + 1 ) || 1;

    for my $task ( @{ $self->find_matching_tasks } ) {
        my $changesets = $self->_recode_task(
            task         => $task,
            transactions => $self->find_matching_transactions(
                task => $task->{id}, starting_transaction => $first_rev
            ),
        );
        $args{'callback'}->($_) for @$changesets;
    }
}

sub _recode_task {
    my $self = shift;
    my %args = validate( @_, { task => 1, transactions => 1 } );

    my @changesets;

    my $previous_state = $args{'task'};
    for my $txn ( sort { $b->{'id'} <=> $a->{'id'} } @{ $args{'transactions'} } ) {
        my $changeset = Prophet::ChangeSet->new( {
            original_source_uuid => $self->sync_source->uuid,
            original_sequence_no => $txn->{'id'},
        } );

        my $method = 'recode_'. $txn->{type};
        unless ( $self->can( $method ) ) {
            die "Unknown change type $txn->{type}.";
        }

        my $change = $self->$method( task => $args{'task'}, transaction => $txn );

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
        unshift @changesets, $changeset if $changeset->has_changes;
    }
    return \@changesets;
}

sub find_matching_tasks {
    my $self = shift;
    my %args = ();

    if ( my $props = $self->sync_source->props ) {
        while ( my ($k, $v) = each %$props ) { $args{$k} = $v }
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
    my %args = validate( @_, { task => 1, starting_transaction => 1 } );

    my $txns = $self->sync_source->hm->search( 'TaskTransaction', task_id => $args{task} ) || [];
    my @matched;
    for my $txn (@$txns) {
        next if $txn->{'id'} < $args{'starting_transaction'};    # Skip things we've pushed

        next if $self->sync_source->prophet_has_seen_foreign_transaction( $txn->{'id'}, $args{task} );

        $txn->{history_entries} = $self->sync_source->hm->search( 'TaskHistory', transaction_id => $txn->{'id'} );
        $txn->{email_entries}   = $self->sync_source->hm->search( 'TaskEmail',   transaction_id => $txn->{'id'} );
        push @matched, $txn;
    }
    return \@matched;

}

sub add_prop_change {
    my $self = shift;
    my %args = validate( @_, { history_entry => 1, previous_state => 1, change => 1 } );

    my $field = $args{'history_entry'}{'field'};
    my $old   = $args{'history_entry'}{'old_value'};
    my $new   = $args{'history_entry'}{'new_value'};

    if ( $args{'previous_state'}->{ $field } eq $new ) {
        $args{'previous_state'}->{ $field } = $old;
    } else {
        $args{'previous_state'}->{ $field } = $old;
        warn $args{'previous_state'}->{ $field } . " != " . $new . "\n\n";
    }

    $args{change}->add_prop_change( name => $field, old => $old, new => $new );
}

sub recode_create {
    my $self = shift;
    my %args = validate( @_, { task => 1, transaction => 1 } );

    my $source = $self->sync_source;
    my $res = Prophet::Change->new( {
        record_type => 'ticket',
        record_uuid => $source->uuid_for_remote_id( $args{'task'}{'id'} ),
        change_type => 'add_file'
    } );

    $args{'task'}{ $source->uuid .'-'. $_ } = delete $args{'task'}{$_}
        for qw(id record_locator);

    while( my ($k, $v) = each %{ $args{'task'} } ) {
        $res->add_prop_change( { name => $k, old => undef, new => $v } );
    }
    return $res;
}

sub recode_update {
    my $self   = shift;
    my %args = validate( @_, { task => 1, transaction => 1 } );

    # In Hiveminder, a changeset has only one change
    my $res = Prophet::Change->new( {
        record_type => 'ticket',
        record_uuid => $self->sync_source->uuid_for_remote_id( $args{'task'}{'id'} ),
        change_type => 'update_file'
    } );

    for my $entry ( @{ $args{'transaction'}{'history_entries'} } ) {
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
                $prop->old_value( $self->sync_source->user_info( 
                    id => $prop->old_value
                )->{'email'} );
                $prop->new_value( $self->sync_source->user_info( 
                    id => $prop->new_value
                )->{'email'} );
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


__PACKAGE__->meta->make_immutable;
no Moose;
1;
