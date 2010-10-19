package App::SD::CLI::Command::Help::Sync;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Sharing ticket databases');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF

    ${cmd}clone --from http://example.com/path/to/sd
      Create a new copy (replica) of a published SD replica from an
      http, ftp or file URL.

    ${cmd}pull --from http://example.com/path/to/sd
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
      computer. Changes will only be accepted from the local machine.

      To clone from this replica use:

          ${cmd}clone --from http://hostname_for_server:9876/replica/

      Adjust port to the server, and notice the /replica/ path.

    ${cmd}browser --port 9876
      Do the same as the server command, but also open up the server's
      front page in your browser.

SD can sync to external systems as well as itself. Currently, there 
are foreign replica types for:

    RT (http://bestpractical.com/rt)
    Hiveminder (http://hiveminder.com/)
    Trac (http://trac.edgewall.com)
    Google Code (http://code.google.com)
    GitHub (http://github.com). 

Read-only support is available for:

     Redmine (http://redmine.org)

If you're interested in building a replica type for your bug 
tracker, you should get in touch with SD's developers (see
http://syncwith.us/contact).

The RT server is specified as as rt:serveraddress|Queue|Query

    ${cmd}clone --from "rt:http://rt3.fsck.com|rt3|Owner='jesse'"
      Create a local replica and pull data from a foreign replica.

    ${cmd}push --to "rt:http://rt3.fsck.com|rt3|Owner='jesse'"
      Push changes to the given foreign replica. Foreign replica
      schemas will vary based on the replica type.

    ${cmd}pull --from "rt:http://rt3.fsck.com|rt3|Owner='jesse'"
      Pull changes from a foreign replica to be merged into the
      local replica.

    Cloning from Google Code

    ${cmd}clone --from gcode:k9mail

    Cloning from Trac

    ${cmd}clone --from trac:https://trac.parrot.org/parrot

    Cloning from GitHub

    ${cmd}clone --from github:miyagawa/remedie

SD uses LWP for HTTP access, so it supports any form of authentication
LWP can use. For instance, you can push and pull from a remote trac
that uses x509 client certificates by setting the HTTPS_CERT_FILE and
HTTPS_KEY_FILE environment variables, and specifying an empty password
when SD prompts you. For more information, see the documentation for
LWP and Crypt::SSLeay.

SD also supports naming replicas, so you can push, pull, and publish
to short, human-friendly names instead of URLs. When a replica is
initialized, cloned, or published, a [replica "name"] section is created in
the replica-specific configuration file (replica_root/config). Its name is, by
default, the URL you passed to the command. You can change this to a more
memorable name with:

    ${cmd}config edit

You can then use sync commands like this:

    ${cmd}pull --from name
    ${cmd}push --to name
    ${cmd}publish --to name

For pull and push, the given name is substituted with the value of the
replica.name.url config variable. For publish, replica.name.publish-url
is used. If different urls are needed for push and pull for a given
replica, you can override replica.name.url with replica.name.push-url
and/or replica.name.pull-url.

EOF

}

    # ${cmd}server --writable --port 9876
    # ${cmd}server -w -p 9876
    #   Start an sd replica server on port 9876, with UNAUTHENTICATED,
    #   PUBLIC WRITE ACCESS via HTTP POST.  This command will make your
    #   replica modifiable, browsable and pullable by ANYONE with remote
    #   access to your computer.

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

