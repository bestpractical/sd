package App::SD::Replica::redmine::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

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

    $self->sync_source->log("Done looking at pulled transactions");

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
    };

    # delete undefined and empty fields
    delete $ticket_data->{$_}
        for grep !defined $ticket_data->{$_} || $ticket_data->{$_} eq '', keys %$ticket_data;

    $self->sync_source->log("Got ticket: $ticket_data->{summary}");

    return $ticket_data, { %$ticket_data };
}

sub transcode_one_txn {
    my ( $self, $txn_wrapper, $ticket, $ticket_final ) = (@_);

    my $txn = $txn_wrapper->{object};

    my $ticket_uuid = $self->sync_source->uuid_for_remote_id( $ticket->{ $self->sync_source->uuid . '-id' } );

    my $changeset = Prophet::ChangeSet->new(
        {   original_source_uuid => $ticket_uuid,
            original_sequence_no => $txn->ticket_id * 10000 + $txn->id,
            creator => 'xxx@example.com',
            created => $txn->date->ymd . " " . $txn->date->hms
        }
    );
    my $change = Prophet::Change->new(
        {   record_type => 'ticket',
            record_uuid => $ticket_uuid,
            change_type => 'add_file'
        }
    );
    $change->add_prop_change(name => "subject", old => "", new => "fnord");
    $changeset->add_change({ change => $change });

    return $changeset;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
