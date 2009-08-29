package App::SD::CLI::Command::Ticket::Update;
use Any::Moose;
use Params::Validate qw/validate/;

extends 'Prophet::CLI::Command::Update';
with 'App::SD::CLI::Model::Ticket';
with 'App::SD::CLI::Command';
with 'Prophet::CLI::TextEditorCommand';

sub ARG_TRANSLATIONS { shift->SUPER::ARG_TRANSLATIONS(),  a => 'all-props'  };

sub usage_msg {
    my $self = shift;
    my $cmd = $self->cli->get_script_name;
    my @primary_commands = @{ $self->context->primary_commands };

    # if primary commands was only length 1, the type was not specified
    # and we should indicate that a type is expected
    push @primary_commands, '<record-type>' if @primary_commands <= 1;

    my $type_and_subcmd = join( q{ }, @primary_commands );

    return <<"END_USAGE";
usage: ${cmd}${type_and_subcmd} <record-id> --edit [--all-props]
       ${cmd}${type_and_subcmd} <record-id> -- status=open
END_USAGE
}

# use an editor to edit if no props are specified on the commandline,
# allowing the creation of a new comment in the process
override run => sub {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    $self->require_uuid;
    my $record = $self->_load_record;

    return super() if ($self->context->prop_names && !$self->has_arg('edit'));
    my $template_to_edit = $self->create_record_template($record);

    my $done = 0;

    while (!$done) {
      $done =  $self->try_to_edit( template => \$template_to_edit, record => $record);
    }

};

sub process_template {
    my $self = shift;
    my %args = validate( @_, { template => 1, edited => 1, record => 1 } );

    my $record      = $args{record};
    my $updated     = $args{edited};
    my ( $props_ref, $comment ) = $self->parse_record_template($updated);

    no warnings 'uninitialized';

    # if a formerly existing prop was removed from the output, delete it
    # (deleting is currently the equivalent of setting to '', and
    # we want to do this all in one changeset)
    for my $prop ( keys %{ $record->get_props } ) {
        next if ( grep { $_ eq $prop } $record->immutable_props );
        $props_ref->{$prop} = ''
            if (!exists $props_ref->{$prop} &&
                # only delete props if they were actually presented
                # for editing in the first place
                grep { $_ eq $prop } $record->props_to_show( {
                        update  => 1,
                        verbose => $self->has_arg('all-props'),
                    } )
            );
    }

    # don't add props that didn't change to the changeset
    for my $prop ( keys %$props_ref ) {
        delete $props_ref->{$prop}
            if $props_ref->{$prop} eq $record->prop($prop);
    }

    # set the new props
    if ( keys %$props_ref ) {
        my $error;
        local $@;
        eval { $record->set_props( props => $props_ref ) }
            or $error = $@ || "Something went wrong!";

        return $self->handle_template_errors(
            error        => $error,
            template_ref => $args{template},
            bad_template => $updated
        ) if ($error);

        print 'Updated ticket ' . $record->luid . ' (' . $record->uuid . ")\n";
    } else {
        print "No changes in properties.\n";
    }

    $self->add_comment( content => $comment, uuid => $record->uuid ) if $comment;
    return 1;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
