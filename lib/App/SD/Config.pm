package App::SD::Config;
use Any::Moose;
use File::Spec;

extends 'Prophet::Config';

# We can't just frob $ENV{PROPHET_APP_CONFIG} the way the sd script does
# with $ENV{PROPHET_REPO} because we need to instantiate App::SD::CLI to
# get the location of the repo root, and then Prophet would load its own
# config file before we got around to messing with the env var
sub app_config_file {
    my $self = shift;

    # The order of preference for config files is:
    #   $ENV{SD_CONFIG} > fs_root/sdrc > fs_root/prophetrc (for backcompat)
    #   $HOME/.sdrc > $ENV{PROPHET_APP_CONFIG} > $HOME/.prophetrc

    $ENV{'PROPHET_APP_CONFIG'}
            =  $self->file_if_exists($ENV{'SD_CONFIG'})
            || $self->file_if_exists(
                File::Spec->catfile($self->app_handle->handle->fs_root => 'config'))
            || $self->file_if_exists(
                # backcompat
                File::Spec->catfile($self->app_handle->handle->fs_root => 'prophetrc'))
            || $self->file_if_exists(
                File::Spec->catfile($ENV{'HOME'}.'/.sdrc'))
            || $ENV{'PROPHET_APP_CONFIG'} # don't overwrite with nothing
            || ''; # don't write undef
        $self->SUPER::app_config_file(@_);
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
