package App::SD::CLI::Command::Help::Tickets;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
        my $self = shift;
            $self->print_header('Working with tickets');
                my $cmd = $self->_get_cmd_name;
                
print <<EOF
 $cmd ticket create
     Invokes a text editor with a ticket creation template
 
 $cmd ticket create --summary="This is a summary" status=open
     Create a new ticket non-interactively
 
 $cmd ticket update 123 -- status=closed
     Sets the status of the ticket with local id 123 to closed 

 $cmd ticket resolve 123
     Sets the status of the ticket with local id 123 to closed 
 
 $cmd ticket update fad5849a-67f1-11dd-bde1-5b33d3ff2799 -- status=closed
     Sets the status of the ticket with uuid 
     fad5849a-67f1-11dd-bde1-5b33d3ff2799 to closed 
EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

