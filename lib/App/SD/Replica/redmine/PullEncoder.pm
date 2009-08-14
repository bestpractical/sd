package App::SD::Replica::redmine::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

# use YAML::XS qw(Dump);
use Params::Validate qw(:all);

has sync_source => (
    isa => 'App::SD::Replica::redmine',
    is  => 'rw',
    required => 1
);

sub ticket_id {
    my ($self, $ticket) = @_;
    return $ticket->id;
}

sub find_matching_tickets {
    my $self = shift;
    my %query = (@_);

    my $redmine = $self->sync_source->redmine;
    my $search = $redmine->search_ticket( $query{query} );

    my @results = $search->results;
    return \@results;
}

sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, starting_transaction => 1 } );

    my @txns;
    my $raw_txn = $args{ticket}->histories;

    for my $txn (@$raw_txn) {
        push @txns, {
            timestamp => $txn->date->epoch,
            serial => $txn->id,
            object => $txn
        }
    }

    # if ($args{ticket}->id == 420) {
    #     die Dump({
    #         ticket_id => $args{ticket}->id,
    #         txn => [ map { { id => $_->{serial}, comment => $_->{comment} } } @txns ]
    #     });
    # }

    return \@txns;
}

sub translate_ticket_state {
    my $self         = shift;
    my $ticket       = shift;
    my $transactions = shift;

    my $final_state = {
        $self->sync_source->uuid . '-id' => $ticket->id,
        status      => lc($ticket->status),
        summary     => $ticket->subject,
        description => $ticket->description,
        priority    => $ticket->priority,
        created     => $ticket->created_at->ymd . " " . $ticket->created_at->hms,
        creator     => $ticket->author->email
    };
    my $initial_state = {%$final_state};

    for my $txn ( sort { $b->{'serial'} <=> $a->{'serial'} } @$transactions ) {
        $txn->{post_state} = { %$final_state };

        if ($txn->{serial} == 0) {
            $txn->{pre_state} = {};
            last;
        }

        my $property_changes = $txn->{object}->property_changes;
        while (my ($name, $changes) = each(%$property_changes)) {
            $initial_state->{$name} = $changes->{from};
        }

        $txn->{pre_state} = {%$initial_state};
    }

    return $initial_state, $final_state;
}

sub transcode_one_txn {
    my $self               = shift;
    my $txn_wrapper        = shift;
    my $older_ticket_state = shift;
    my $newer_ticket_state = shift;

    my $txn = $txn_wrapper->{object};

    if ($txn_wrapper->{serial} == 0) {
        return $self->transcode_create_txn($txn_wrapper, $older_ticket_state, $newer_ticket_state);
    }

    my $ticket_id   = $newer_ticket_state->{ $self->sync_source->uuid . '-id' };
    my $ticket_uuid = $self->sync_source->uuid_for_remote_id($ticket_id);
    my $creator     = $newer_ticket_state->{creator};
    my $created     = $newer_ticket_state->{created};

    my $changeset = Prophet::ChangeSet->new({
        original_source_uuid => $ticket_uuid,
        original_sequence_no => $txn->id,
        creator              => $creator,
        created              => $created,
    });

    my $change = Prophet::Change->new({
        record_type => 'ticket',
        record_uuid => $ticket_uuid,
        change_type => 'update_file',
    });

    for my $prop ( keys %{ $txn_wrapper->{post_state} } ) {
        my $new = $txn_wrapper->{post_state}->{$prop};
        my $old = $txn_wrapper->{pre_state}->{$prop};

        next unless defined($new) && defined($old);

        $change->add_prop_change(
            name => $prop,
            new  => $new,
            old  => $old,
        ) unless $new eq $old;
    }

    $changeset->add_change({ change => $change });

    $self->_include_change_comment($changeset, $ticket_uuid, $txn);
    return $changeset;
}

sub _include_change_comment {
    my $self        = shift;
    my $changeset   = shift;
    my $ticket_uuid = shift;
    my $txn         = shift;

    my $comment = $self->new_comment_creation_change();

    my $content = $txn->note || "";

    if ( $content !~ /^\s*$/s ) {
        $comment->add_prop_change(
            name => 'created',
            new  => $txn->date->ymd . ' ' . $txn->date->hms,
        );
        $comment->add_prop_change(
            name => 'creator',
            new => 'ccc@example.com',
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

sub transcode_create_txn {
    my $self        = shift;
    my $txn         = shift;
    my $create_data = shift;
    my $final_data  = shift;

    my $ticket_id   = $final_data->{ $self->sync_source->uuid . '-id' };
    my $ticket_uuid = $self->sync_source->uuid_for_remote_id($ticket_id);
    my $creator     = 'xxx@example.com';
    my $created     = $final_data->{created};

    my $changeset = Prophet::ChangeSet->new({
        original_source_uuid => $ticket_uuid,
        original_sequence_no => 0,
        creator              => $creator,
        created              => $created,
    });

    my $change = Prophet::Change->new({
        record_type => 'ticket',
        record_uuid => $ticket_uuid,
        change_type => 'add_file',
    });

    while ( my ($name, $value) = each %{ $txn->{post_state} }) {
        $change->add_prop_change(
            name => $name,
            new => $value
        )
    }

    $changeset->add_change({ change => $change });

    # for my $att ( @{ $txn->{object}->attachments } ) {
    #     $self->_recode_attachment_create(
    #         ticket_uuid => $ticket_uuid,
    #         txn         => $txn->{object},
    #         changeset   => $changeset,
    #         attachment  => $att,
    #     );
    # }

    return $changeset;
}

sub translate_prop_status {}

sub resolve_user_id_to {
    my $self = shift;
    my $to   = shift;
    my $id   = shift;
    return $id;
}


__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
