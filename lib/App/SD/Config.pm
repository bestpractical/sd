package App::SD::Config;
use Any::Moose;
use File::Spec;

extends 'Prophet::Config';

{
### XXX This code is for BACKCOMPAT ONLY! Eventually, we want to kill it
### completely.

sub _old_app_config_file {
    my $self = shift;

    # The order of preference for (OLD!) config files is:
    #   $ENV{SD_CONFIG} > fs_root/config > fs_root/prophetrc (for backcompat)
    #   $HOME/.sdrc > $ENV{PROPHET_APP_CONFIG} > $HOME/.prophetrc

    # if we set PROPHET_APP_CONFIG here, it will mess up legit uses of the
    # new config file setup
    my $old_file 
            =  $self->_file_if_exists($ENV{'SD_CONFIG'})
            || $self->_file_if_exists( File::Spec->catfile($self->app_handle->handle->fs_root => 'config'))
            || $self->_file_if_exists( File::Spec->catfile($self->app_handle->handle->fs_root => 'prophetrc'))
            || $self->_file_if_exists( File::Spec->catfile($ENV{'HOME'}.'/.sdrc'))
            || $ENV{'PROPHET_APP_CONFIG'} # don't overwrite with nothing
            || ''; # don't write undef

    return $self->_file_if_exists($old_file)
        || $self->_file_if_exists( File::Spec->catfile( $ENV{'HOME'} => '.prophetrc' ))
        || $self->_file_if_exists( File::Spec->catfile( $self->app_handle->handle->fs_root => 'config' )) ||
     $self->_file_if_exists( File::Spec->catfile( $self->app_handle->handle->fs_root => 'prophetrc' )) ||
      File::Spec->catfile( $self->app_handle->handle->fs_root => 'config' );
}



override load => sub  {
    my $self = shift;

    Prophet::CLI->end_pager();

    # Do backcompat stuff.
    for my $file ( ($self->_old_app_config_file, $self->dir_file, $self->user_file, $self->global_file) ) {
        my $content = -f $file ? Prophet::Util->slurp($file) : '[';

        # config file is old

        # Also "converts" empty files but that's fine. If it ever
        # does happen, we get the positive benefit of writing the
        # config format to it.
        if ( $content !~ /\[/ ) {

            $self->convert_ancient_config_file($file);
        }

    }

    Prophet::CLI->start_pager();

    # Do a regular load.
    $self->SUPER::load(@_);
};

### XXX BACKCOMPAT ONLY! We eventually want to kill this hash, modifier and
### the following methods.

# None of these need to have values mucked with at all, just the keys
# migrated from old to new.
our %KEYS_CONVERSION_TABLE = (
    'email_address' => 'user.email-address',
    'default_group_ticket_list' => 'ticket.default-group',
    'default_sort_ticket_list' => 'ticket.default-sort',
    'summary_format_ticket' => 'ticket.summary-format',
    'default_summary_format' => 'record.summary-format',
    'common_ticket_props' => 'ticket.common-props',
    'disable_ticket_show_history_by_default' => 'ticket.no-implicit-history-display',
);



sub convert_ancient_config_file {
            my $self = shift;
            my $file = shift;
            print "Detected old format config file $file. Converting to ".
                  "new format... ";

            # read in and parse old config
            my $config = { _sources => {}, _aliases => {} };
            $self->_load_old_config_from_file( $file, $config );
            my $aliases = delete $config->{_aliases};
            my $sources = delete $config->{_sources};

            # new configuration will include a config format version #
            my @config_to_set = ( {
                    key => 'core.config-format-version',
                    value => $self->FORMAT_VERSION,
            } );

            # convert its keys to new-style keys by comparing to a conversion
            # table
            for my $key ( keys %$config ) {
                die "Unknown key '$key' in old format config file '$file'."
                    ." Remove it or ask\non irc.freenode.net #prophet if you"
                    ." think this is a bug.\n"
                        unless exists $KEYS_CONVERSION_TABLE{$key};
                push @config_to_set, {
                    key   => $KEYS_CONVERSION_TABLE{$key},
                    value => $config->{$key},
                };
            }
            # convert its aliases
            for my $alias ( keys %$aliases ) {
                push @config_to_set, {
                    key   => "alias.'$alias'",
                    value => $aliases->{$alias},
                };
            }
            # convert its sources
            for my $name ( keys %$sources ) {
                my ($url, $uuid) = split(/ \| /, $sources->{$name}, 2);
                push @config_to_set, {
                    key   => "replica.'$name'.url",
                    value => $url,
                }, {
                    key   => "replica.'$name'.uuid",
                    value => $uuid,
                };
            }
            # move the old config file to a backup
            my $backup_file = $file;
            unless ( $self->_deprecated_repo_config_names->{$file} ) {
                $backup_file = "$file.bak";
                rename $file, $backup_file;
            }

            # we want to write the new file to a supported filename if
            # it's from a deprecated config name (replica/prophetrc)
            $file = File::Spec->catfile( $self->app_handle->handle->fs_root, 'config' )
                if $self->_deprecated_repo_config_names->{$file};

            # write the new config file (with group_set)
            $self->group_set( $file, \@config_to_set, 1);

            # tell the user that we're done
            print "done.\nOld config can be found at $backup_file; "
                  ,"new config is $file.\n\n";

}

sub _deprecated_repo_config_names {
    my $self = shift;

    my %filenames = ( File::Spec->catfile( $self->app_handle->handle->fs_root => 'prophetrc' ) => 1 );

    return wantarray ? %filenames : \%filenames;
};
sub _load_old_config_from_file {
    my $self   = shift;
    my $file   = shift;
    my $config = shift || {};

    for my $line (Prophet::Util->slurp($file) ) {
        $line =~ s/\#.*$//; # strip comments
        next unless ($line =~ /^(.*?)\s*=\s*(.*)$/);
        my $key = $1;
        my $val = $2;
        if ($key =~ m!alias\s+(.+)!) {
            $config->{_aliases}->{$1} = $val;
        } elsif ($key =~ m!source\s+(.+)!) {
            $config->{_sources}->{$1} = $val;
        } else {
            $config->{$key} = $val;
        }
    }
    $config->{_aliases} ||= {}; # default aliases is null.
    $config->{_sources} ||= {}; # default to no sources.
}

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
