package App::SD::CLI::Command::Help;
use Moose;
extends 'Prophet::CLI::Command';
with 'App::SD::CLI::Command';

sub run {

my $cmd = $0;
$cmd =~ s{^(.*)/}{}g;

print <<EOF
sd @{[$App::SD::VERSION]}

= Searching for and displaying tickets
 
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
 

= Working with tickets

 $cmd ticket create
     Invokes a text editor with a ticket creation template
 
 $cmd ticket create --summary="This is a summary" status=open
     Create a new ticket non-interactively
 
 $cmd ticket update 123 -- status=closed
     Sets the status of the ticket with local id 123 to closed 
 
 $cmd ticket update fad5849a-67f1-11dd-bde1-5b33d3ff2799 -- status=closed
     Sets the status of the ticket with uuid 
     fad5849a-67f1-11dd-bde1-5b33d3ff2799 to closed 
 

== Working with ticket comments

 $cmd ticket comment 456
     Add a comment to the ticket with id 456, popping up a text editor
 
 $cmd ticket comment 456 --file=myfile
     Add a comment to the ticket with id 456, using the content of 'myfile'
 
 $cmd ticket comment list
     List all ticket comments 
 
 $cmd ticket comment show 4
     Show ticket comment 4 and all metadata


== Working with ticket attachments
 
 $cmd ticket attachment create 456 --file bugfix.patch
     Create a new attachment on this ticket from the file 'bugfix.patch'.    
 
 $cmd ticket attachment list 456
     Show all attachemnts on ticket 456
 
 $cmd ticket attachment content 567
     Send the content of attachment 567 to STDOUT
 
 $cmd ticket resolve 123
     Sets the status of the ticket with local id 123 to closed 


= Sharing ticket databases
 
 $cmd pull --from http://example.com/path/to/sd
    Integrate changes from a published SD replica over http, ftp or 
    file URL schemes.
 
 $cmd pull --all
    Integrate changes from all replicas this replica has pulled from
    before

 $cmd pull --local
    Integrate changes from all replicas currently announcing themselves
    on the local network using Bonjour
 
 $cmd publish --to jesse\@server:path/to/destination
    Publish a copy of this replica to a remote server using rsync over
    ssh.

 $cmd publish --html --replica --to jesse\@server:path/to/destination
    Publish a copy of this replica, including a static html representation,
    to a remote server using rsync over ssh.

 
= ENVIRONMENT

  export SD_REPO=/path/to/sd/replica
    Specify where the ticket database SD is using should reside

EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

