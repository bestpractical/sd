package App::SD::Replica::hm::PushEncoder;
use Any::Moose;

extends 'App::SD::ForeignReplica::PushEncoder';

use Params::Validate;
use Data::Dumper;
use Path::Class;
has sync_source => (
    isa => 'App::SD::Replica::hm',
    is  => 'rw'
);

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset )
        = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );

    # Build up a ticket object out of all the record's attributes
    my %args = (
        owner           => 'me',
        group           => 0,
        complete        => 0,
        will_complete   => 1,
        repeat_stacking => 0,
        %{ $self->_recode_props_for_create($change) }
    );

    my $hm_user = $self->sync_source->user_info(email => $self->sync_source->foreign_username);

    my @requesters;
    if ( $args{'requestor_id'} ) {
        require Email::Address;

        my $pusher_is_requester = 0;

        @requesters = Email::Address->parse( $args{'requestor_id'} );
        @requesters = grep {
            lc( $_->address ) eq lc( $hm_user->{'email'} ) ? do { $pusher_is_requester = 1; 0 } : 1
        } @requesters;

        unless ($pusher_is_requester) {

            # XXX: this doesn't work, HM is too protective
            #            unless ( $hm_user->{'pro_account'} ) {
            #                warn "Only pro accounts can set requestor in HM";
            $args{'requestor_id'} = $hm_user->{'email'};

            #            }
            #            else {
            #                $args{'requestor_id'} = shift(@requesters)->format;
            #            }
        } else {
            $args{'requestor_id'} = $hm_user->{'email'};
        }
        if (@requesters) {
            warn "A ticket has more than one requestor when HM supports only one";
        }
    }

    my $task = $self->sync_source->hm->create( 'Task', %args );
    unless ( $task->{'success'} ) {
        die "Couldn't create a task: " . $self->decode_error($task);
    }

    my $tid = $task->{content}->{id};

    if (@requesters) {
        my $email = $self->comment_as_email(
            {   creator => $hm_user->{'email'},
                content => "Additional requestors: " . join( ', ', map $_->format, @requesters ),
            }
        );
        my $status = $self->sync_source->hm->act(
            'CreateTaskEmail',
            task_id => $tid,
            message => $email->as_string,
        );
        warn "Couldn't add a comment on the recently created HM task"
            unless $status->{'success'};
    }

    my $txns = $self->sync_source->hm->search( 'TaskTransaction', task_id => $tid );

    # lalala
    $self->sync_source->record_pushed_transaction(
        transaction => $txns->[0]->{id},
        changeset   => $changeset,
        record      => $tid
    );

    return $tid;
}

sub decode_error {
    my $self   = shift;
    my $status = shift;
    my $msg    = '';
    $msg .= $status->{'error'} if defined $status->{'error'};
    if ( $status->{'field_errors'} ) {
        while ( my ( $k, $v ) = each %{ $status->{'field_errors'} } ) {
            $msg .= "field '$k' - '$v'\n";
        }
    }
    return $msg;
}

sub integrate_comment {
    my $self = shift;
    my ( $change, $changeset )
        = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;

    my $ticket_id = $self->sync_source->remote_id_for_uuid( $props{'ticket'} )
        or die "Couldn't get remote id of SD ticket";

    my $email  = $self->comment_as_email( \%props );
    my $status = $self->sync_source->hm->act(
        'CreateTaskEmail',
        task_id => $ticket_id,
        message => $email->as_string,
    );
    return $status->{'content'}{'id'} if $status->{'success'};

    die "Couldn't integrate comment: " . $self->decode_error($status);
}

sub integrate_ticket_update {
    my $self = shift;
    my ( $change, $changeset )
        = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );

    my %args = $self->translate_props($change);
    return unless keys %args;

    my $tid = $self->sync_source->remote_id_for_uuid( $change->record_uuid )
        or die "Couldn't get remote id of SD ticket";

    my ( $seen_current, $dropped_all, @new_requestors ) = ( 0, 0 );
    if (   exists $args{'requestor_id'}
        && defined $args{'requestor_id'}
        && length $args{'requestor_id'} )
    {
        my $task = $self->sync_source->hm->read( 'Task', id => $tid );
        my $current_requestor = $self->sync_source->user_info( id => $task->{'requester_id'} );

        require Email::Address;
        @new_requestors = Email::Address->parse( delete $args{'requestor_id'} );
        @new_requestors = grep {
            ( lc( $_->address ) eq lc( $current_requestor->{'email'} ) )
                ? do { $seen_current = 1; 0; }
                : 1
        } @new_requestors;

        unless ($seen_current) {
            warn "Requestor can not be changed in HM";
        }
        if ( ( @new_requestors && $seen_current ) || @new_requestors > 1 ) {
            warn "Can not set more than one requestor in HM";
        }
    } elsif ( exists $args{'requestor_id'} ) {
        $dropped_all = 1;
        delete $args{'requestor_id'};
        warn "Requestor can not be empty in HM";
    }

    my $txn_id;
    if ( keys %args ) {
        my $status = $self->sync_source->hm->act(
            'UpdateTask',
            id => $tid,
            %args,
        );
        die "Couldn't integrate ticket update: " . $self->decode_error($status)
            unless $status->{'success'};
        $txn_id = $status->{'content'}{'id'};
    }

    if (@new_requestors) {
        my $comment_id = $self->record_comment(
            task    => $tid,
            content => (
                $seen_current
                ? "New requestors in addition to the current: "
                : "Requestors have been changed: "
                )
                . join( ', ', map $_->format, @new_requestors ),
        );
        $txn_id = $comment_id if $comment_id;
    } elsif ($dropped_all) {
        my $comment_id = $self->record_comment(
            task    => $tid,
            content => "All requestors have been deleted",
        );
        $txn_id = $comment_id if $comment_id;
    }

    return $txn_id;
}

sub record_comment {
    my $self = shift;
    my %args = @_;
    my $tid  = delete $args{'task'};
    $args{'creator'} ||= $self->sync_source->user_info->{'email'};

    my $email  = $self->comment_as_email( \%args );
    my $status = $self->sync_source->hm->act(
        'CreateTaskEmail',
        task_id => $tid,
        message => $email->as_string,
    );
    warn "Couldn't add a comment on the recently created HM task"
        unless $status->{'success'};
    return $status->{'content'}{'id'};
}

sub integrate_attachment {
    my $self = shift;
    my ( $change, $changeset )
        = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );

    unless ( $self->sync_source->user_info->{'pro_account'} ) {
        warn "Pro account is required to push attachments";
        return;
    }

    my %props = $self->translate_props($change);
    $props{'content'} = {
        content      => $props{'content'},
        filename     => delete $props{'name'},
        content_type => delete $props{'content_type'},
    };

    my $ticket_id = $self->sync_source->remote_id_for_uuid( delete $props{'ticket'} )
        or die "Couldn't get remote id of SD ticket";

    my $status = $self->sync_source->hm->act(
        'CreateTaskAttachment',
        task_id => $ticket_id,
        %props,
    );
    return $status->{'content'}{'id'} if $status->{'success'};

    die "Couldn't integrate attachment: " . $self->decode_error($status);
}

sub _recode_props_for_create {
    my $self = shift;
    my $attr = $self->_recode_props_for_integrate(@_);

    my $source_props = $self->sync_source->props;
    return $attr unless $source_props;

    my %source_props = %$source_props;
    for ( grep exists $source_props{$_}, qw(group owner requestor) ) {
        $source_props{ $_ . '_id' } = delete $source_props{$_};
    }

    if ( $source_props{'tag'} ) {
        if ( defined $attr->{'tags'} && length $attr->{'tags'} ) {
            $attr->{'tags'} .= ', ' . $source_props{'tag'};
        } else {
            $attr->{'tags'} .= ', ' . $source_props{'tag'};
        }
    }
    if ( $source_props{'tag_not'} ) {
        die "TODO: not sure what to do here and with other *_not search arguments";
    }

    return { %$attr, %source_props };
}

sub comment_as_email {
    my $self  = shift;
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

    my %props = $self->translate_props($change);

    my %attr;
    for my $key ( keys %props ) {
        $attr{$key} = $props{$key};
    }
    return \%attr;
}

sub translate_props {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %PROP_MAP = $self->sync_source->property_map('push');

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    delete $props{$_} for @{ delete $PROP_MAP{'_delete'} };
    while ( my ( $k, $v ) = each %PROP_MAP ) {
        next unless exists $props{$k};
        $props{$v} = delete $props{$k};
    }
    return %props;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
