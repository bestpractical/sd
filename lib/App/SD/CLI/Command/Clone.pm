package App::SD::CLI::Command::Clone;
use Any::Moose;
extends 'Prophet::CLI::Command::Clone';
with 'App::SD::CLI::NewReplicaCommand';

sub ARG_TRANSLATIONS {
    shift->SUPER::ARG_TRANSLATIONS(),
    # this arg is used in the new_replica_wizard sub
    n => 'non-interactive',
};

sub usage_msg {
    my $self = shift;
    my $cmd = $self->cli->get_script_name;

    return <<"END_USAGE";
usage: ${cmd}clone --from <url> [--as <alias>] [--non-interactive] | --local

Options:
    -n | --non-interactive - Don't prompt to specify email address for new
                             database
    --as                   - Save an alias for this source, which can later be
                             used instead of the URL.
    --local                - Probe the local network for mDNS-advertised
                             replicas and list them.
END_USAGE
}

override run => sub {
    my $self = shift;

    # clone dies if the target replica already exists, so no need
    # to worry about not running the wizard if the clone doesn't run
    $self->SUPER::run();

    Prophet::CLI->end_pager();

    # Prompt for SD setup (specifically email address for changes) after the
    # clone, but *don't* immediately edit the database's settings, since a
    # cloned database should have already been setup previously.
    $self->new_replica_wizard( edit_settings => 0 );
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

