package App::SD::CLI::Command::Ticket::Comment::Create;
use Any::Moose;

extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::TicketComment';
with 'App::SD::CLI::Command';

sub ARG_TRANSLATIONS { shift->SUPER::ARG_TRANSLATIONS(),  f => 'file', m => 'content'  };

sub usage_msg {
    my $self = shift;
    my ($cmd, $type_and_subcmd) = $self->get_cmd_and_subcmd_names;

    return <<"END_USAGE";
usage: ${cmd}${type_and_subcmd} <ticket-id> [--edit]
       ${cmd}${type_and_subcmd} <ticket-id> -- content="message here"
END_USAGE
}

# override args to feed in that ticket's uuid as an argument to the comment
sub run {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    $self->require_uuid;

    my $content = $self->get_content(type => 'comment', default_edit => 1);

    die "Aborted.\n"
        if length($content) == 0;

    $self->set_prop(ticket => $self->uuid);
    $self->set_prop(content => $content);
    $self->SUPER::run(@_);
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

