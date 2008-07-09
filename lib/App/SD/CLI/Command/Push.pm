package App::SD::CLI::Command::Push;
use Moose;
extends qw/App::SD::CLI::Command::Merge/;

sub run {
    my $self = shift;
    local $ENV{PROPHET_RESOLVER} = 'Prompt';
    bless $self, 'App::SD::CLI::Command::Merge';
    $self->args( {to => $self->args->{'to'}, from => $self->app_handle->default_replica_type.":file://".$self->app_handle->handle->fs_root });
    $self->run;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

