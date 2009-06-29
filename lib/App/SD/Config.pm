package App::SD::Config;
use Any::Moose;
use File::Spec;

extends 'Prophet::Config';

### XXX This class is for BACKCOMPAT ONLY! Eventually, we want to kill it
### completely.

override _old_app_config_file => sub {
    my $self = shift;

    # The order of preference for (OLD!) config files is:
    #   $ENV{SD_CONFIG} > fs_root/config > fs_root/prophetrc (for backcompat)
    #   $HOME/.sdrc > $ENV{PROPHET_APP_CONFIG} > $HOME/.prophetrc

    # if we set PROPHET_APP_CONFIG here, it will mess up legit uses of the
    # new config file setup
    $ENV{'OLD_PROPHET_APP_CONFIG'}
            =  $self->_file_if_exists($ENV{'SD_CONFIG'})
            || $self->_file_if_exists(
                File::Spec->catfile($self->app_handle->handle->fs_root => 'config'))
            || $self->_file_if_exists(
                # backcompat
                File::Spec->catfile($self->app_handle->handle->fs_root => 'prophetrc'))
            || $self->_file_if_exists(
                File::Spec->catfile($ENV{'HOME'}.'/.sdrc'))
            || $ENV{'PROPHET_APP_CONFIG'} # don't overwrite with nothing
            || ''; # don't write undef
        $self->SUPER::_old_app_config_file(@_,
            config_env_var => 'OLD_PROPHET_APP_CONFIG');
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
