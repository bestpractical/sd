package App::SD::CLI::Command::Pull;
use Moose;
extends qw/App::SD::CLI::Command::Merge/;

override run => sub {
    my $self = shift;

    die "Please specify a --from.\n" if !defined($self->args->{'from'});

    local $ENV{PROPHET_RESOLVER} = 'Prompt';

    $self->set_arg(to => $self->cli->app_handle->default_replica_type.":file://".$self->cli->app_handle->handle->fs_root);

    super();
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

