package App::SD::Replica::redmine::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

use YAML::XS qw(Dump);
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

    return \@txns;
}

sub translate_ticket_state {
    my $self         = shift;
    my $ticket       = shift;
    my $transactions = shift;


    my $ticket_data = {
        $self->sync_source->uuid . '-id' => $ticket->id,
        status      => ( $ticket->status  || undef ),
        summary     => ( $ticket->subject || undef ),
        description => ( $ticket->description || undef ),
        priority    => ( $ticket->priority || undef ),
        created_at  => ( $ticket->created_at->ymd . " " . $ticket->created_at->hms )
    };

    # delete undefined and empty fields
    delete $ticket_data->{$_}
        for grep !defined $ticket_data->{$_} || $ticket_data->{$_} eq '', keys %$ticket_data;

    return $ticket_data, { %$ticket_data };
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

    return;

    my $ticket_id   = $newer_ticket_state->{ $self->sync_source->uuid . '-id' };
    my $ticket_uuid = $self->sync_source->uuid_for_remote_id($ticket_id);
    my $creator     = $self->resolve_user_id_to( email_address => $newer_ticket_state->{reporter} );
    my $created     = $newer_ticket_state->{created};

    my $changeset = Prophet::ChangeSet->new(
        {
            original_source_uuid => $ticket_uuid,
            original_sequence_no => 0,
            creator              => $creator,
            created              => $created,
        }
    );

    my $change = Prophet::Change->new(
        {
            record_type => 'ticket',
            record_uuid => $ticket_uuid,
            change_type => 'update_file',
        }
    );

    for my $prop ( keys %{ $txn->{post_state} } ) {
        $change->add_prop_change(
            name => $prop,
            new  => ref( $txn->{post_state}->{$prop} ) eq 'ARRAY'
            ? join( ', ', @{ $txn->{post_state}->{$prop} } )
            : $txn->{post_state}->{$prop},
        );
    }
    $changeset->add_change( { change => $change } );

    return $changeset;
}

sub transcode_create_txn {
    my $self        = shift;
    my $txn         = shift;
    my $create_data = shift;
    my $final_data  = shift;

    my $ticket_id   = $final_data->{ $self->sync_source->uuid . '-id' };
    my $ticket_uuid = $self->sync_source->uuid_for_remote_id($ticket_id);
    my $creator     = 'xxx@example.com';
    my $created     = $final_data->{created_at};

    my $changeset = Prophet::ChangeSet->new(
        {
            original_source_uuid => $ticket_uuid,
            original_sequence_no => 0,
            creator              => $creator,
            created              => $created,
        }
    );

    my $change = Prophet::Change->new(
        {
            record_type => 'ticket',
            record_uuid => $ticket_uuid,
            change_type => 'add_file',
        }
    );

    for my $prop ( keys %{ $txn->{post_state} } ) {
        $change->add_prop_change(
            name => $prop,
            new  => ref( $txn->{post_state}->{$prop} ) eq 'ARRAY'
            ? join( ', ', @{ $txn->{post_state}->{$prop} } )
            : $txn->{post_state}->{$prop},
        );
    }
    $changeset->add_change( { change => $change } );

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

sub _include_change_comment {}

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
