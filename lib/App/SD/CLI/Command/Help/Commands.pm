package App::SD::CLI::Command::Help::Commands;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    $self->print_header('Summary of SD commands');
    my ${cmd}= $self->cli->get_script_name;

print <<EOF

The commonly used SD commands are:

    help      view built-in documentation
    init      initialise a new replica
    clone     clone an existing local or remote replica
    publish   publish a replica so others can pull from / clone it
    pull      pull in new changesets from another replica
    push      push changesets to a foreign replica
    server    run a local web interface
    browser   run a local web interface and open it up in a browser
    log       view changesets
    shell     spawn an interactive shell
    version   view version information
    config    view and modify configuration
    aliases   view and modify aliases
    settings  manage replica-specific settings

  For operating on tickets:

    create (new)    make a new ticket
    search (list)   list tickets matching criteria
    show (basics)   show basic info about a ticket
    details         show detailed info about a ticket
    comment         create a new comment on a ticket
    comments        show all comments belonging to a ticket
    update (edit)   change info about a ticket
    delete (rm)     delete a ticket

  For operating on ticket comments:

    create (new)    make a new ticket comment
    update (edit)   change info about a ticket comment
    delete (rm)     delete a ticket comment

  For operating on ticket attachments:

    create (new)    make a new ticket attachment
    content         display an attachment
    delete (rm)     delete a ticket attachment

Commands that operate on a record must be run with the record
type specified. See the examples given in specific help documents.
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

