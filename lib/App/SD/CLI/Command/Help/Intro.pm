package App::SD::CLI::Command::Help::Intro;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Getting started with SD');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF
SD is a peer to peer ticket tracking system built on the Prophet
distributed database. SD is designed to make it easy to work with tickets
and to share ticket databases with your collaborators.

To get started with SD, you need a ticket database. To get a ticket
database, you have two options: You can clone an existing database
or start a new one.

SD will store its local database replica in the path specified by the
SD_REPO environment variable. Generally, you will want to use a shell
script or alias wrapper to set this variable if you have more than one
SD replica. Two scripts distributed with SD will set SD_REPO from the
VCS of the project directory you're currently in: git-sd and darcs-sd.
If you write a wrapper for another VCS, please contribute it back!

To clone a ticket database:

    ${cmd}clone --from http://example.com/path/to/sd

To start a new ticket database:

    ${cmd}init

Or, using the git-sd script within a project checkout:

    git sd init

To configure your project's name, milestones and components:

    ${cmd}settings edit

To create a ticket, run:

    ${cmd}ticket create

To list all tickets in your database:

    ${cmd}ticket list

To publish your database:

    ${cmd}publish joeuser\@myhost.example.com:public_html/mydb

To learn a bit more about what you can do with SD:

    ${cmd}help
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

