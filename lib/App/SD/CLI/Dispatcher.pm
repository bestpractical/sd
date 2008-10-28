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

on ['ticket', 'give', qr/.*/, qr/.*/] => sub {
    my $self = shift;
    $self->context->set_arg(type  => 'ticket');
    $self->context->set_arg(id    => $3);
    $self->context->set_arg(owner => $4);
    run('update', $self, @_);
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

__PACKAGE__->meta->make_immutable;
no Moose;

1;

