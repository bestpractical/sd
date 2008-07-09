package App::SD::CLI::Command::Pull;
use Moose;
extends qw/App::SD::CLI::Command::Merge/;

sub run {
    my $self = shift;

    die "Please specify a --from.\n" if !defined($self->args->{'from'});

    local $ENV{PROPHET_RESOLVER} = 'Prompt';
    bless $self, 'App::SD::CLI::Command::Merge';
    $self->args({  from => $self->args->{'from'},
                   to => $self->cli->app_handle->default_replica_type.":file://".$self->cli->app_handle->handle->fs_root });
    $self->run;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

