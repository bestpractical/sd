package App::SD::CLI::Command::Help::Tickets;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Creating and Updating tickets');
    my $cmd = $self->_get_cmd_name;

print <<EOF
    $cmd ticket create
      Invokes a text editor with a ticket creation template.
      Note that 'new' is an alias for 'create'.

    $cmd ticket create --verbose
      Invokes a text editor with a ticket creation template
      and also shows descriptions and valid values for
      properties.

    $cmd ticket create -- summary="This is a summary" status=open
      Create a new ticket non-interactively.

    $cmd ticket update 123 -- status=closed
      Sets the status of the ticket with local id 123 to closed.
      Note that 'edit' is an alias for 'update'.

    $cmd ticket update 123
      Interactively update the ticket with local id 123 in a text
      editor.

    $cmd ticket update 123 --verbose
      Interactively update the ticket with local id 123 in a text
      editor and show descriptions and valid values for props.

    $cmd ticket update 123 --all-props
      Interactively update the ticket with local id 123 in a text
      editor, presenting all the props of the record for editing instead of
      just those specified by the database setting 'default_props_to_show'.

    $cmd ticket update fad5849a-67f1-11dd-bde1-5b33d3ff2799 -- status=closed
      Sets the status of the ticket with uuid
      fad5849a-67f1-11dd-bde1-5b33d3ff2799 to closed.

    $cmd ticket resolve 123
      Sets the status of the ticket with local id 123 to closed.

    $cmd ticket resolve 123 --edit
      Sets the status of the ticket with local id 123 to closed,
      allowing you to edit any properties in an editor and
      optionally add a comment in the process.
EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

