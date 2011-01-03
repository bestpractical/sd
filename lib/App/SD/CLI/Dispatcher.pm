#!/usr/bin/env perl
package App::SD::CLI::Dispatcher;
use Prophet::CLI::Dispatcher -base;
use Any::Moose;
require Prophet::CLIContext;
use File::Basename;

Prophet::CLI::Dispatcher->add_command_prefix('App::SD::CLI::Command');

# "sd ?about" => "sd help about"
rewrite qr/^\?(.*)/ => sub { "help ".($1||'') };

# 'sd about' -> 'sd help about', 'sd copying' -> 'sd help copying'
rewrite [ ['about', 'copying'] ] => sub { "help $1" };

on qr'^(?!help)' => sub {
    my $self = shift;
    my $cmd = $_;

    if ($self->context->has_arg('help')) {
        run("help $cmd", $self, @_);
    }
    elsif ($self->context->has_arg('version')
            || $self->context->has_arg('V') ) {
        $self->context->delete_arg('version');
        $self->context->delete_arg('V');
        run("version", $self);
    }
    else {
        next_rule;
    }
};

under help => sub {
    on [ [ 'intro', 'init' ] ]   => run_command('Help::Intro');
    on about   => run_command('Help::About');
    on config  => run_command('Help::Config');
    on copying => run_command('Help::Copying');
    on commands => run_command('Help::Commands');
    on [ ['summary-format', 'ticket.summary-format', 'ticket_summary_format'] ]
        => run_command('Help::ticket_summary_format');

    on [ ['author', 'authors'] ]         => run_command('Help::Authors');
    on [ ['environment', 'env'] ]        => run_command('Help::Environment');
    on [ ['ticket', 'tickets'] ]         => run_command('Help::Tickets');
    on [ ['attach', 'attachment', 'attachments'] ] => run_command('Help::Attachments');
    on [ ['comment', 'comments'] ]       => run_command('Help::Comments');
    on [ ['setting', 'settings'] ]       => run_command('Help::Settings');
    on [ ['history', 'log'] ]            => run_command('Help::History');
    on [ ['alias', 'aliases'] ]          => run_command('Help::Aliases');

    on [
        ['ticket', 'attachment', 'comment'],
        ['list', 'search', 'find'],
    ] => run_command('Help::Search');

    # anything else under ticket, e.g. 'ticket close' etc. should be covered
    # in the tickets help
    on qr/^ticket/ => run_command('Help::Tickets');

    on [ ['search', 'list', 'find'] ] => run_command('Help::Search');

    on [ ['sync', 'push', 'pull', 'publish', 'server', 'browser', 'clone'] ]
        => run_command('Help::Sync');

    on qr/^(\S+)$/ => sub {
       my $self = shift;
       my $topic = $1;
       die "Cannot find help on topic '$topic'. Try '".$self->cli->get_script_name()."help'?\n";
    };
};

on help => run_command('Help');

on qr'.*' => sub {
    my $self = shift;

    unless ( $self->cli->app_handle->local_replica_url ||
        $self->cli->context->has_arg('h') ) {

        print join "\n",
            "",
            "It appears that you haven't specified a local replica path.",
            "You can do so by setting the SD_REPO environment variable.",
            "",
            " 'sd help intro' will tell you a bit about how to get started with sd.",
            " 'sd help' will show show you a list of help topics.",
            "", "";

        exit 1;
    }
    next_rule;
};

on qr'.*' => sub {
    my $self = shift;
    my $command = $_;
    next_rule if $command =~ /^(?:shell|clone|init)$|(config|alias(?:es)?)/;
    next_rule if $self->cli->app_handle->handle->replica_exists;

    print join("\n","No SD database was found at " . $self->cli->app_handle->handle->url(),
               qq{Type "} . $self->cli->get_script_name(). qq{help init" or "}. 
               $self->cli->get_script_name().qq{help environment" for tips on how to sort that out.});
    exit 1;
};

on browser => run_command('Browser');

# allow doing some things backwards -- e.g. 'list tickets' etc.
on qr/^(\w+)\s+tickets?(.*)$/ => sub {
    my $self = shift;
    my $primary = $1;
    my $secondary = $2;
    next_rule if $primary eq 'help';
    my $cmd = join( ' ', grep { $_ ne '' } 'ticket',$primary, $secondary);
    my @orig_argv = @{$self->cli->context->raw_args};
    my ($subcommand, undef) = (shift @orig_argv, shift @orig_argv);
    $self->cli->run_one_command( 'ticket', $subcommand, @orig_argv);
};

under ticket => sub {
    # all these might possibly have IDs tacked onto the end
    on
    qr/^((?:comment\s+)?(?:comments?|update|edit|show|details|display|delete|del|rm|history|claim|take|resolve|basics|close)) $Prophet::CLIContext::ID_REGEX$/i => sub {
        my $self = shift;
        $self->context->set_id_from_primary_commands;
        run("ticket $1", $self, @_);
    };

    on [ [ 'new'    , 'create' ] ]    => run_command('Ticket::Create');
    on [ [ 'show'   , 'display' ] ]   => run_command('Ticket::Show');
    on [ [ 'update' , 'edit' ] ]      => run_command('Ticket::Update');
    on [ [ 'search', 'list', 'ls' ] ] => run_command('Ticket::Search');
    on review   => run_command('Ticket::Review');
    on details  => run_command('Ticket::Details');
    on basics   => run_command('Ticket::Basics');
    on comment  => run_command('Ticket::Comment');
    on comments => run_command('Ticket::Comments');

    under [ [ 'give', 'assign' ] ] => sub {
        on [qr/^$Prophet::CLIContext::ID_REGEX$/, qr/^\S+$/] => sub {
            my $self = shift;
            my ($id, $owner) = ($1, $2);

            $self->context->set_arg(id     => $id);
            $self->context->set_arg(type   => 'ticket');
            $self->context->set_prop(owner => $owner);
            $self->context->set_type_and_uuid;
            run('ticket update', $self, @_);
        };
        on qr/^(.*)$/ => sub {
            die "Usage: give <id> <email>\n";
        };
    };

    on [ ['resolve', 'close'] ] => sub {
        my $self = shift;
        $self->context->set_prop(status => 'closed');
        run('ticket update', $self, @_);
    };

    # simulate a 'claim' command by setting the owner prop and passing
    # off to update
    on [ [ 'claim', 'take' ] ] => sub {
        my $self = shift;
        my $email = $self->context->app_handle->current_user_email;
        if ($email) {
            $self->context->set_prop(owner => $email);
            run('ticket update', $self, @_);
        } else {
            die "Could not determine email address to assign ticket to!\n".
                "Set the 'user.email-address' config variable.\n";
        }
    };

    under comment => sub {
        on create => run_command('Ticket::Comment::Create');
        on update => run_command('Ticket::Comment::Update');
    };

    under attachment => sub {
        on create => run_command('Ticket::Attachment::Create');
        on [ [ 'create', 'new' ], qr/^$Prophet::CLIContext::ID_REGEX$/ ] => sub {
            my $self = shift;
            $self->context->set_id_from_primary_commands;
            run('ticket attachment create', $self, @_);
        };
        on search => run_command('Ticket::Attachment::Search');
    };


};

under attachment => sub {
    on qr/^(.*)\s+($Prophet::CLIContext::ID_REGEX)$/i => sub {
        my $self = shift;
        my $next = $1;
        my $id = $2;
        $self->context->set_id($id);
        run("attachment $next", $self, @_);
    };

    on content => run_command('Attachment::Content');
    on create  => run_command('Attachment::Create');
};

# allow type to be specified via primary commands, e.g.
# 'sd ticket display --id 14' -> 'sd display --type ticket --id 14'
on qr{^(ticket|comment|attachment) \s+ (.*)}xi => sub {
    my $self = shift;
    my $type = $1;
    my $redispatch_to = $2;
    $self->context->set_arg(type => $type);
    run($redispatch_to, $self, @_);
};

redispatch_to('Prophet::CLI::Dispatcher');

on '' => run_command('Shell');

on qr/^(.*)$/ => sub {
   my $self = shift;
   my $command = $1;
   die "The command you ran, '$command', could not be found. Perhaps running '"
        .$self->cli->get_script_name."help' would help?\n";

};

sub run_command { Prophet::CLI::Dispatcher::run_command(@_) }

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

