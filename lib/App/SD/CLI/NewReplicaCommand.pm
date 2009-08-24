package App::SD::CLI::NewReplicaCommand;
use Any::Moose 'Role';

# steal email from $ENV{EMAIL} or prompt, and prompt to edit settings
sub new_replica_wizard {
    my $self = shift;
    my %args = (
        edit_settings => 1,
        @_,
    );

    # VCS wrappers themselves should take care of settings email addresses on
    # init/clone from VCS configuration, don't put that here

    # non-interactive option is useful for testing and scriptability
    unless ( $self->has_arg('non-interactive') ) {
        # don't prompt for configuration if there's already a user-wide email set
        if ( ! defined $self->config->get( key => 'user.email-address' ) ) {

            print "\nYou need an email address configured to use SD. I'll try"
                ." to find one.\n";

            if ( $ENV{PROPHET_EMAIL} ) {
                $self->_migrate_email_from_env( 'PROPHET_EMAIL' );
            }
        }
        if ( ! defined $self->config->get( key => 'user.email-address' ) ) {
            if ( $ENV{EMAIL} ) {
                $self->_migrate_email_from_env( 'EMAIL' );
            }
        }
        # if we still don't have an email, ask
        if ( ! defined $self->config->get( key => 'user.email-address' ) ) {
            $self->_prompt_email;
        }

        # new replicas probably want to change settings right away,
        # at least to change the project name ;)
        $self->_prompt_edit_settings if $args{edit_settings};
    }

    # this message won't print if the user has a ~/.sdrc, which is
    # probably a pretty good indication that they're not new
    my $script = $self->cli->get_script_name;
    print <<"END_MSG" unless -f $self->config->user_file;

If you're new to SD, you can find out what to do now by looking at
'${script}help intro' and '${script}help tickets'. You can see a list of all
help topics with '${script}help'. Have fun!
END_MSG
}

# default is the replica-specific config file
sub _prompt_which_config_file {
    my $self = shift;
    my $email = shift;

    print "\nUse '$email' for (a)ll your bug databases, (j)ust"
            ." this one,\nor (n)ot at all? [a/J/n] ";
    chomp( my $response = <STDIN> );

    my $config_file = lc $response eq 'a'
        ? $self->config->user_file
        : lc $response eq 'n'
        ? undef
        : $self->config->replica_config_file;

    return $config_file;
}

sub _migrate_email_from_env {
    my $self = shift;
    my $var = shift;

    print "Found '$ENV{$var}' in \$$var.\n";
    my $config_file = $self->_prompt_which_config_file( $ENV{$var} );

    if ( $config_file ) {
        $self->config->set(
            key      => 'user.email-address',
            value    => $ENV{$var},
            filename => $config_file,
        );
        print "  - added email '$ENV{$var}' to\n    $config_file\n";
    }
}

sub _prompt_email {
    my $self = shift;

    Prophet::CLI->end_pager(); # XXX where does this get turned back on?
    print "\nCouldn't determine an email address to attribute your SD changes to.\n";

    my $email;
    while ( ! $email ) {
        print "What email shall I use? ";
        chomp( $email = <STDIN> );
    }

    my $use_dir_config = $self->prompt_choices( 'j', 'a',
        'Use this for (a)ll your SD databases or (j)ust this one?' );

    my $config_file = $use_dir_config
                    ? $self->config->replica_config_file
                    : $self->config->user_file;
    $self->config->set(
        key      => 'user.email-address',
        value    => $email,
        filename => $config_file,
    );
    print "  - added email '$email' to\n    $config_file\n";
}

sub _prompt_edit_settings {
    my $self = shift;

    my $prompt_for_settings
        = $self->prompt_Yn(
            "\nWant to edit your new bug database's settings now?" );
    if ( $prompt_for_settings ) {
        my @classes = App::SD::CLI::Dispatcher->class_names('Settings');
        for my $class (@classes) {
            $self->app_handle->try_to_require($class) or next;

            # reset args for new command
            my $args = {
                edit => 1,
            };
            $self->context->mutate_attributes( args => $args );

            my $command = $class->new(
                uuid    => $self->context->uuid,
                cli     => $self->cli,
                context => $self->context,
            );
            $command->run();
        }

    }
}

no Any::Moose;

1;

