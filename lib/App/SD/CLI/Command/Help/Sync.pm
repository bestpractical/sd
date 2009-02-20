package App::SD::CLI::Command::Help::Sync;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Sharing ticket databases');
    my ${cmd}= $self->_get_cmd_name;

print <<EOF

    ${cmd}clone http://example.com/path/to/sd
      Create a new copy (replica) of a published SD replica from an
      http, ftp or file URL.

    ${cmd}pull http://example.com/path/to/sd
      Integrate changes from a published SD replica over http, ftp or 
      file URL.

    ${cmd}pull --all (or -a)
      Integrate changes from all replicas this replica has pulled from
      before.

    ${cmd}pull --local (or -l)
      Integrate changes from all replicas currently announcing themselves
      on the local network using Bonjour.

    ${cmd}publish --to jesse\@server:path/to/destination
      Publish a copy of this replica to a remote server using rsync.

    ${cmd}publish --html --replica --to jesse\@server:path/to/destination
      Publish a copy of this replica, including a static html representation,
      to a remote server using rsync.

    ${cmd}server --port 9876
      Start an sd replica server on port 9876. This command will make your 
      replica browsable and pullable by anyone with remote access to your 
      computer.

    ${cmd}server --writable --port 9876
      Start an sd replica server on port 9876, with UNAUTHENTICATED,
      PUBLIC WRITE ACCESS via HTTP POST.  This command will make your
      replica modifiable, browsable and pullable by ANYONE with remote
      access to your computer.

    ${cmd}server -w -p 9876
      -w is a shortcut for --writable and -p is a shortcut for --port
      for this command.

SD can sync to external systems as well as itself. Currently, there are foreign
replica types for RT (http://bestpractical.com/rt) and Hiveminder
(http://hiveminder.com/). If you're interested in building a replica type for
your bug tracker, you should get in touch with SD's developers (see
http://syncwith.us/contact).

    ${cmd}push --to rt:http://rt3.fsck.com|rt3|Owner='jesse'
      Push changes to the given foreign replica. Foreign replica
      schemas will vary based on the replica type.

    ${cmd}pull --from rt:http://rt3.fsck.com|rt3|Owner='jesse'
      Pull changes from a foreign replica to be merged into the
      local replica.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

