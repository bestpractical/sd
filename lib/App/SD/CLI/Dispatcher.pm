#!/usr/bin/env perl
package App::SD::CLI::Dispatcher;
use Prophet::CLI::Dispatcher -base;
use Moose;

Prophet::CLI::Dispatcher->add_command_prefix('App::SD::CLI::Command');

# "sd ?about" => "sd help about"
rewrite qr/^\?(.*)/ => sub { "help ".($1||'') };

# 'sd about' -> 'sd help about', 'sd copying' -> 'sd help copying'
rewrite [ ['about', 'copying'] ] => sub { "help $1" };


under help => sub {
    on [ [ 'intro', 'init', 'clone' ] ]   => run_command('Help::Intro');
    on about   => run_command('Help::About');
    on config  => run_command('Help::Config');
    on copying => run_command('Help::Copying');
    on summary_format_ticket => run_command('Help::summary_format_ticket');

    on [ ['author', 'authors'] ]         => run_command('Help::Authors');
    on [ ['environment', 'env'] ]        => run_command('Help::Environment');
    on [ ['ticket', 'tickets'] ]         => run_command('Help::Tickets');
    on [ ['attachment', 'attachments'] ] => run_command('Help::Attachments');
    on [ ['comment', 'comments'] ]       => run_command('Help::Comments');
    on [ ['setting', 'settings'] ]       => run_command('Help::Settings');
    on [ ['history', 'log'] ]            => run_command('Help::History');
    on [ ['alias', 'aliases'] ]          => run_command('Help::Aliases');

    on [
        ['ticket', 'attachment', 'comment'],
        ['list', 'search', 'find'],
    ] => run_command('Help::Search');

    on [ ['search', 'list', 'find'] ] => run_command('Help::Search');

    on [ ['sync', 'push', 'pull', 'publish', 'server'] ]
        => run_command('Help::Sync');

    on qr/^(\S+)$/ => sub {
       my $self = shift;
       my $topic = $1;
       die "Cannot find help on topic '$topic'. Try '$0 help'?\n";
    };
};

on help => run_command('Help');

under ticket => sub {
    on [ [ 'search', 'list', 'ls' ] ] => run_command('Ticket::Search');
    on [ [ 'new',    'create' ] ]  => run_command('Ticket::Create');
    on [ [ 'show',   'display' ] ] => run_command('Ticket::Show');
    on [ [ 'update', 'edit' ] ]    => run_command('Ticket::Update');
    on basics   => run_command('Ticket::Basics');
    on comments => run_command('Ticket::Comments');
    on comment  => run_command('Ticket::Comment');
    on details  => run_command('Ticket::Details');

    under [ [ 'give', 'assign' ] ] => sub {
        on [qr/^(?:\d+|[0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12})$/, qr/^\S+$/] => sub {
            my $self = shift;
            my ($id, $owner) = ($1, $2);

            $self->context->set_arg(id    => $id);
            $self->context->set_arg(type    => 'ticket');
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
        my $email = $self->context->app_handle->config->get('email_address')
                        || $ENV{EMAIL};

        if ($email) {
            $self->context->set_prop(owner => $email);
            run('ticket update', $self, @_);
        } else {
            die "Could not determine email address to assign ticket to ".
                "(set \$EMAIL\nor the 'email' config variable.)\n";
        }
    };

    under comment => sub {
        on [ [ 'new', 'create' ] ] => run_command('Ticket::Comment::Create');
        on [ [ 'update', 'edit' ] ] => run_command('Ticket::Comment::Update');
    };

    under attachment => sub {
        on create => run_command('Ticket::Attachment::Create');
        on search => run_command('Ticket::Attachment::Search');
    };


};

under attachment => sub {
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
   die "The command you ran, '$command', could not be found. Perhaps running '$0 help' would help?\n";

};

sub run_command {Prophet::CLI::Dispatcher::run_command(@_) }


__PACKAGE__->meta->make_immutable;
no Moose;

1;

