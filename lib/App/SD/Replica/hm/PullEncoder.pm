package App::SD::Replica::hm::PullEncoder;
use Moose;
use Params::Validate qw(:all);
use Memoize;

has sync_source => (
    isa => 'App::SD::Replica::hm',
    is => 'rw',
);

our $DEBUG = $Prophet::Handle::DEBUG;

sub run {
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
        foreach my $email ( @{ $txn->{email_entries} } ) {
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
        warn $args{'previous_state'}->{ $field } . " != " . $new . "\n\n"
            . YAML::Dump( \%args );
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
        foreach qw(id record_locator);

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

    foreach my $entry ( @{ $args{'transaction'}{'history_entries'} } ) {
        $self->add_prop_change(
            change         => $res,
            history_entry  => $entry,
            previous_state => $args{'task'},
        );
    }
    return $res;
}

sub resolve_user_id_to_email {
    my $self = shift;
    my $id   = shift;
    return undef unless ($id);

    return $self->sync_source->hm->email_of($id);
}

memoize 'resolve_user_id_to_email';

sub warp_list_to_old_value {
    my $self       = shift;
    my $task_value = shift || '';
    my $add        = shift;
    my $del        = shift;

    my @new = split( /\s*,\s*/, $task_value );
    my @old = grep { $_ ne $add } @new, $del;
    return join( ", ", @old );
}

our $MONNUM = {
    Jan => 1,
    Feb => 2,
    Mar => 3,
    Apr => 4,
    May => 5,
    Jun => 6,
    Jul => 7,
    Aug => 8,
    Sep => 9,
    Oct => 10,
    Nov => 11,
    Dec => 12
};

our %PROP_MAP = (
    owner_id                 => 'owner',
    requestor_id             => 'reported_by',
    priority                 => 'priority_integer',
    completed_at             => 'completed',
    due                      => 'due',
    creator                  => 'creator',
    attachment_count         => '_delete',
    depended_on_by_count     => '_delete',
    depended_on_by_summaries => '_delete',
    depends_on_count         => '_delete',
    depends_on_summaries     => '_delete',
    group_id                 => '_delete',
    last_repeat              => '_delete',
    repeat_days_before_due   => '_delete',
    repeat_every             => '_delete',
    repeat_of                => '_delete',
    repeat_next_create       => '_delete',
    repeat_period            => '_delete',
    repeat_stacking          => '_delete',

);

sub translate_props {
    my $self      = shift;
    my $changeset = shift;

    for my $change ( $changeset->changes ) {
        next unless $change->record_type eq 'ticket';
        my @new_props;
        for my $prop ( $change->prop_changes ) {
            $prop->name( $PROP_MAP{ lc( $prop->name ) } ) if $PROP_MAP{ lc( $prop->name ) };
            next if ( $prop->name eq '_delete' );

            if ( $prop->name =~ /^(?:reported_by|owner|next_action_by)$/ ) {
                $prop->old_value( $self->resolve_user_id_to_email( $prop->old_value ) );
                $prop->new_value( $self->resolve_user_id_to_email( $prop->new_value ) );
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
