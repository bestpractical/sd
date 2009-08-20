package App::SD::CLI::Command::Init;
use Any::Moose;
extends 'Prophet::CLI::Command::Init';
with 'App::SD::CLI::NewReplicaCommand';

sub ARG_TRANSLATIONS {
    shift->SUPER::ARG_TRANSLATIONS(),
    n => 'non-interactive',
};

override run => sub {
    my $self = shift;

    $self->SUPER::run();

    Prophet::CLI->end_pager();

    $self->new_replica_wizard();
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

