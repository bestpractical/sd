package App::SD::CLI::Command::Ticket::Create;
use Any::Moose;

use Params::Validate qw/validate/;
extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::Ticket';
with 'App::SD::CLI::Command';
with 'Prophet::CLI::TextEditorCommand';

around ARG_TRANSLATIONS => sub { shift->(),  e => 'edit'  };

# we want to launch an $EDITOR window to grab props and a comment if no
# props are specified on the commandline

override run => sub {
    my $self = shift;
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
        error        => $error,
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
