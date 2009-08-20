package App::SD::CLI::Command::Help::Comments;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Working with ticket comments');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF

    ${cmd}ticket comment 456
      Add a comment to the ticket with id 456, popping up a text editor.

    ${cmd}ticket comment 456 --file=myfile
    ${cmd}ticket comment 456 -f myfile
      Add a comment to the ticket with id 456, using the content of 'myfile'.

    ${cmd}ticket comment 456 --content="The text of the comment."
    ${cmd}ticket comment 456 -m "The text of the comment."
      Add a comment to the ticket with id 456, specifying its content on
      the commandline.

    ${cmd}ticket comment list
      List all ticket comments.

    ${cmd}ticket comment show 4
      Show ticket comment 4 and all metadata.

    ${cmd}ticket comments 9
      Show all comments belonging to the ticket with id 9.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

