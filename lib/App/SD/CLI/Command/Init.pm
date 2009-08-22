package App::SD::CLI::Command::Init;
use Any::Moose;
extends 'Prophet::CLI::Command::Init';
with 'App::SD::CLI::NewReplicaCommand';

sub usage_msg {
    my $self = shift;
    my $cmd = $self->cli->get_script_name;

    return <<"END_USAGE";
usage: ${cmd}init [--non-interactive]

Options:
    -n | --non-interactive - Don't prompt to edit settings or specify email
                             address for new database
END_USAGE
}

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

