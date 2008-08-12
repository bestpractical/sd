package App::SD::CLI::Command::Help::Attachments;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Working with ticket attachments');
    my $cmd = $self->_get_cmd_name;

print <<EOF
== Working with ticket attachments
 
 $cmd ticket attachment create 456 --file bugfix.patch
     Create a new attachment on this ticket from the file 'bugfix.patch'.    
 
 $cmd ticket attachment list 456
     Show all attachemnts on ticket 456
 
 $cmd ticket attachment content 567
     Send the content of attachment 567 to STDOUT
EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

