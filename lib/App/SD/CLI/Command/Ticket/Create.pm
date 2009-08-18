package App::SD::CLI::Command::Ticket::Create;
use Any::Moose;

use Params::Validate qw/validate/;
extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::Ticket';
with 'App::SD::CLI::Command';
with 'Prophet::CLI::TextEditorCommand';

sub ARG_TRANSLATIONS { shift->SUPER::ARG_TRANSLATIONS(),  e => 'edit'  };

# use actual valid ticket props in the help message, and make note of the
# interactive editing mode
override usage_msg => sub {
    my $self = shift;
    my $cmd = $self->cli->get_script_name;

    my @primary_commands = @{ $self->context->primary_commands };

    # if primary commands was only length 1, the type was not specified
    # and we should indicate that a type is expected
    push @primary_commands, '<record-type>' if @primary_commands == 1;

    my $type_and_subcmd = join( q{ }, @primary_commands );

    return <<"END_USAGE";
usage: ${cmd}${type_and_subcmd} -- summary=foo status=open
       ${cmd}${type_and_subcmd} [--edit]
END_USAGE
};

# we want to launch an $EDITOR window to grab props and a comment if no
# props are specified on the commandline

override run => sub {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    my @prop_set = $self->prop_set;
    my $record = $self->_get_record_object;

    # only invoke editor if no props specified on the commandline or edit arg specified
    return super() if (@{$self->prop_set} && !$self->has_arg('edit'));

    my $template_to_edit = $self->create_record_template();

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
    ( my $props_ref, my $comment ) = $self->parse_record_template($updated);

    for my $prop ( keys %$props_ref ) {
        $self->context->set_prop( $prop => $props_ref->{$prop} );
    }

    my $error;
        local $@;
        eval { super(); } or chomp ($error = $@ || "Something went wrong!");

    return $self->handle_template_errors(
        error        => $error . "\n\nYou can bypass validation for a "
                        ."property by appending a ! to it.",
        template_ref => $args{template},
        bad_template => $updated,
        rtype        => $record->type,
    ) if ($error);

    $self->add_comment( content => $comment, uuid => $self->record->uuid )
        if $comment;

    return 1;
}



__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
