package App::SD::Replica::redmine::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

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
    my ($self, $ticket_id, $start_transaction) = @_;

    return [];
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


__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
