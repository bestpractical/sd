package App::SD::Replica::redmine::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

has sync_source => (
    isa => 'App::SD::Replica::redmine',
    is  => 'rw',
    required => 1,
);

sub run {
    my $self = shift;
    my @tickets = @{ $self->find_matching_tickets() };

    if ( @tickets == 0 ) {
        $self->sync_source->log("No tickets found.");
        return;
    }

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
