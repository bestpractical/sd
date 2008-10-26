package App::SD::Config;
use Moose;
use File::Spec;

extends 'Prophet::Config';

# We can't just frob $ENV{PROPHET_APP_CONFIG} the way the sd script does
# with $ENV{PROPHET_REPO} because we need to instantiate App::SD::CLI to
# get the location of the repo root, and then Prophet would load its own
# config file before we got around to messing with the env var
before 'app_config_file' => sub {
    my $self = shift;

    $ENV{'PROPHET_APP_CONFIG'} = $self->file_if_exists($ENV{'SD_CONFIG'})
            || $self->file_if_exists(
                File::Spec->catfile($self->app_handle->handle->fs_root => 'sdrc'))
            || $self->file_if_exists(
                # backcompat
                File::Spec->catfile($self->app_handle->handle->fs_root => 'prophetrc'))
            || $self->file_if_exists(
                File::Spec->catfile($ENV{'HOME'}.'/.sdrc'));
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;
