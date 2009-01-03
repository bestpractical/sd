package App::SD::CLI::Command::Help::Intro;
use Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Getting started with SD');
    my $cmd = $self->_get_cmd_name;

print <<EOF
SD is a peer to peer ticket tracking system built on the Prophet 
distributed database. SD is designed to make it easy to work with tickets
and to share ticket databases with your collaborators.

To get started with SD, you need an ticket database. To get an ticket 
database, you have two options: You can clone an existing database
or start a new one.

SD will store its local database replica in the ".sd" directory in your 
home directory. You can override this behaviour by setting the SD_REPO
environment variable.

To clone an ticket database:

    $cmd clone --from http://example.com/path/to/sd

To start a new ticket database:

    $cmd init

To create a ticket, run:

    $cmd ticket create

To publish your database:

    $cmd publish --to joeuser\@myhost.example.com:public_html/mydb

To learn a bit more about what you can do with SD:
    
    $cmd help

EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

