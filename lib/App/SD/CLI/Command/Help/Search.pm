package App::SD::CLI::Command::Help::Search;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Searching for and displaying tickets');
    my $cmd = $self->_get_cmd_name;

print <<EOF
 $cmd ticket search
     Lists all tickets with a status that does not match 'closed'
 
 $cmd ticket search --regex abc
     Lists all tickets with content matching 'abc'
 
 $cmd ticket search -- status!=closed summary =~ http 
     Lists all tickets with a status that does match closed
     and a summary matching 'http'
 
 $cmd ticket show 1234
     Show basic information for the ticket with local id 1234
 
 $cmd ticket details 1234
     Show basic information and history for the ticket with local id 1234
 
 $cmd ticket history 1234
     Show history for the ticket with local id 1234
 
 $cmd ticket delete 1234
     Deletes ticket with local id 1234
EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

