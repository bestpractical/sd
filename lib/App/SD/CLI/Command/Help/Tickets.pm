package App::SD::CLI::Command::Help::Tickets;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Creating and Updating tickets');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF
    ${cmd}ticket create
      Invokes a text editor with a ticket creation template.
      Note that 'new' is an alias for 'create'.

    ${cmd}ticket create --verbose
    ${cmd}ticket create -v
      Invokes a text editor with a ticket creation template
      and also shows descriptions and valid values for
      properties.

    ${cmd}ticket create -- summary="This is a summary" status=open
      Create a new ticket non-interactively.

    ${cmd}ticket update 123 -- status=closed
      Sets the status of the ticket with local id 123 to closed.
      Note that 'edit' is an alias for 'update'.

    ${cmd}ticket update 123
      Interactively update the ticket with local id 123 in a text
      editor.

    ${cmd}ticket update 123 --verbose
    ${cmd}ticket update 123 -v
      Interactively update the ticket with local id 123 in a text
      editor and show descriptions and valid values for props.

    ${cmd}ticket update 123 --all-props
    ${cmd}ticket update 123 -a
      Interactively update the ticket with local id 123 in a text
      editor, presenting all the props of the record for editing instead of
      just those specified by the database setting 'common_ticket_props'
      (or local configuration variable 'common_ticket_props' if it exists).

    ${cmd}ticket update fad5849a-67f1-11dd-bde1-5b33d3ff2799 -- status=closed
      Sets the status of the ticket with uuid
      fad5849a-67f1-11dd-bde1-5b33d3ff2799 to closed.

    ${cmd}ticket take 123
      Sets the owner of ticket 123 to you (your email address is taken
      from either the 'email_address' local config variable or the
      EMAIL environmental variable). An alias of 'take' is 'claim'.

    ${cmd}ticket give 123 nobody\@example.com
      Sets the owner of ticket 123 to nobody\@example.com.
      An alias of 'give' is 'assign'.

    ${cmd}ticket resolve 123
    ${cmd}ticket close 123
      Sets the status of the ticket with local id 123 to closed.

    ${cmd}ticket resolve 123 --edit
    ${cmd}ticket resolve 123 -e
      Sets the status of the ticket with local id 123 to closed,
      allowing you to edit any properties in an editor and
      optionally add a comment in the process.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

