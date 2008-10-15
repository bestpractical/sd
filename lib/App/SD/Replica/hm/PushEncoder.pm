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
        %{ $self->_recode_props_for_create($change) }
    );

    my $txns = $self->sync_source->hm->search( 'TaskTransaction', task_id => $task->{content}->{id} );

    # lalala
    $self->sync_source->record_pushed_transaction( transaction => $txns->[0]->{id}, changeset => $changeset );
    return $task->{content}->{id};
}

sub integrate_comment {
    my $self = shift;
    my ($change, $changeset) = validate_pos( @_, { isa => 'Prophet::Change' }, {isa => 'Prophet::ChangeSet'} );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;

    my $ticket_id = $self->sync_source->remote_id_for_uuid( $props{'ticket'} )
        or die "Couldn't get remote id of SD ticket";

    my $email = $self->comment_as_email( \%props );
    my $status = $self->sync_source->hm->act( 'CreateTaskEmail',
        task_id => $ticket_id,
        message => $email->as_string,
    );
    return $status->{'content'}{'id'} if $status->{'success'};

    die "Couldn't integrate comment: ". $status->{'error'};
}

sub integrate_ticket_update {
    warn "update not implemented yet";
}

sub _recode_props_for_create {
    my $self = shift;
    my $attr = $self->_recode_props_for_integrate(@_);
    my $source_props = $self->sync_source->props;
    return $attr unless $source_props;

    my %source_props = %$source_props;
    for (grep exists $source_props{$_}, qw(group owner requestor)) {
        $source_props{$_.'_id'} = delete $source_props{$_};
    }

    if ( $source_props{'tag'} ) {
        if ( defined $attr->{'tags'} && length $attr->{'tags'} ) {
            $attr->{'tags'} .= ', '. $source_props{'tag'};
        } else {
            $attr->{'tags'} .= ', '. $source_props{'tag'};
        }
    }
    if ( $source_props{'tag_not'} ) {
        die "TODO: not sure what to do here and with other *_not search arguments";
    }

    return { %$attr, %source_props };
}

sub comment_as_email {
    my $self = shift;
    my $props = shift;

    require Email::Simple;
    require Email::Simple::Creator;

    my $res = Email::Simple->create(
        header => [
            From => $props->{'creator'},
            Date => $props->{'created'},
        ],
        body => $props->{'content'},
    );
    return $res;
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

