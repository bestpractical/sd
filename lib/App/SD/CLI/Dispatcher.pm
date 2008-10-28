#!/usr/bin/env perl
package App::SD::CLI::Dispatcher;
use Prophet::CLI::Dispatcher -base;
use Moose;

on qr'^\?(.*)$' => sub {my $cmd = $1 || ''; run('help'. $cmd, @_); last_rule;};

# 'sd about' -> 'sd help about', 'sd copying' -> 'sd help copying'
on [ ['about', 'copying'] ] => sub { run("help $1", @_); };

under help => sub {
    rewrite [ ['push', 'pull', 'publish', 'server'] ] => 'help sync';
    rewrite 'env' => 'help environment';
    rewrite 'ticket' => 'help tickets';
    rewrite [ 'ticket', ['list', 'search', 'find'] ] => 'help search';
    rewrite [ ['list', 'find'] ] => 'help search';
};

under ticket => sub {
    on create   => run_command('Ticket::Create');
    on basics   => run_command('Ticket::Basics');
    on comments => run_command('Ticket::Comments');
    on comment  => run_command('Ticket::Comment');
    on details  => run_command('Ticket::Details');
    on search   => run_command('Ticket::Search');
    on show     => run_command('Ticket::Show');
    on update   => run_command('Ticket::Update');

    on ['give', qr/.*/, qr/.*/] => sub {
        my $self = shift;
        $self->context->set_arg(type  => 'ticket');
        $self->context->set_arg(id    => $2);
        $self->context->set_arg(owner => $3);
        run('update', $self, @_);
    };

    on ['resolve', 'close'] => sub {
        my $self = shift;
        $self->context->set_prop(status => 'closed');
        run('ticket update', $self, @_);
    };

    under comment => sub {
        on create => run_command('Ticket::Attachment::Create');
        on update => run_command('Ticket::Attachment::Update');
    };

    under attachment => sub {
        on create => run_command('Ticket::Attachment::Create');
        on search => run_command('Ticket::Attachment::Search');
    };
};

# allow type to be specified via primary commands, e.g.
# 'sd ticket display --id 14' -> 'sd display --type ticket --id 14'
on qr{^(ticket|comment|attachment) \s+ (.*)}xi => sub {
    my $self = shift;
    $self->context->set_arg(type => $1);
    run($2, $self, @_);
};

__PACKAGE__->dispatcher->add_rule(
    Path::Dispatcher::Rule::Dispatch->new(
        dispatcher => Prophet::CLI::Dispatcher->dispatcher,
    ),
);

sub run_command { Prophet::CLI::Dispatcher::run_command(@_) }

sub class_names {
    my $self = shift;
    my $name = shift;

    ("App::SD::CLI::Command::$name", $self->SUPER::class_names($name, @_));
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

