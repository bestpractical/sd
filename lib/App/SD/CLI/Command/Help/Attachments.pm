package App::SD::CLI::Command::Help::Attachments;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Working with ticket attachments');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF

    ${cmd}ticket attachment create 456 --file bugfix.patch
    ${cmd}ticket attachment create 456 -f bugfix.patch
      Create a new attachment on this ticket from the file 'bugfix.patch'.

    ${cmd}ticket attachment list 456
      Show all attachemnts on ticket 456.

    ${cmd}ticket attachment show 567
      Show the properties of attachment 567 (including the content).

    ${cmd}ticket attachment content 567
      Send the content of attachment 567 to STDOUT.

    ${cmd}ticket attachment content 567 > to_apply.patch
      Save the contents of attachment 567 to a file so the patch
      can be applied.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

