package App::SD::Replica::hm::PushEncoder;
use Moose; 
use Params::Validate;
use Path::Class;
has sync_source => 
    ( isa => 'App::SD::Replica::hm',
      is => 'rw');


sub integrate_change {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );
    my $id;
    eval {
        if (    $change->record_type eq 'ticket'
            and $change->change_type eq 'add_file' 
    )
        {
            $id = $self->integrate_ticket_create( $change, $changeset );
            $self->sync_source->record_pushed_ticket(
                uuid      => $change->record_uuid,
                remote_id => $id
            );

        } elsif ( $change->record_type eq 'attachment'
            and $change->change_type eq 'add_file' 
        
        ) {
            $id = $self->integrate_attachment( $change, $changeset );
        } elsif ( $change->record_type eq 'comment' 
            and $change->change_type eq 'add_file' 
        ) {
            $id = $self->integrate_comment( $change, $changeset );
        } elsif ( $change->record_type eq 'ticket' ) {
            $id = $self->integrate_ticket_update( $change, $changeset );

        } else {
            return undef;
        }

        $self->sync_source->record_pushed_transactions(
            ticket    => $id,
            changeset => $changeset
        );

    };
    warn $@ if $@;
    return $id;
}



sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );

    # Build up a ticket object out of all the record's attributes

    my $task = $self->sync_source->hm->create(
        'Task',
        owner           => 'me',
        group           => 0,
        requestor       => 'me',
        complete        => 0,
        will_complete   => 1,
        repeat_stacking => 0,
        %{ $self->_recode_props_for_integrate($change) }

    );

    my $txns = $self->sync_source->hm->search( 'TaskTransaction', task_id => $task->{content}->{id} );

    # lalala
    $self->sync_source->record_pushed_transaction( transaction => $txns->[0]->{id}, changeset => $changeset );
    return $task->{content}->{id};

    #    return $ticket->id;

}

sub integrate_comment {
    warn "comment not implemented yet";
}

sub integrate_ticket_update {
    warn "update not implemented yet";
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        # XXX: fill me in
        #        next unless ( $key =~ /^(summary|queue|status|owner|custom)/ );
        $attr{$key} = $props{$key};
    }
    return \%attr;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

