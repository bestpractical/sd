
package App::SD::CLI::Command::Help::Sync;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Sharing ticket databases');
    my $cmd = $self->_get_cmd_name;

print <<EOF

 $cmd clone --from http://example.com/path/to/sd
    Create a new copy (replica) of a published SD replica from an
    http, ftp or file URL.

 $cmd pull --from http://example.com/path/to/sd
    Integrate changes from a published SD replica over http, ftp or 
    file URL.
 
 $cmd pull --all
    Integrate changes from all replicas this replica has pulled from
    before.

 $cmd pull --local
    Integrate changes from all replicas currently announcing themselves
    on the local network using Bonjour
 
 $cmd publish --to jesse\@server:path/to/destination
    Publish a copy of this replica to a remote server using rsync.

 $cmd publish --html --replica --to jesse\@server:path/to/destination
    Publish a copy of this replica, including a static html representation,
    to a remote server using rsync.

 $cmd server --port 9876
    Start an sd replica server on port 9876. This command will make your 
    replica browsable and pullable by anyone with remote access to your 
    computer.

 $cmd server --writable --port 9876
    Start an sd replica server on port 9876, with UNAUTHENTICATED,
    PUBLIC WRITE ACCESS via HTTP POST.  This command will make your
    replica modifiable, browsable and pullable by ANYONE with remote
    access to your computer.

EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

