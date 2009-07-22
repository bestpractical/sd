package App::SD::CLI::Command::Ticket::Attachment::Create;
use Any::Moose;
extends 'App::SD::CLI::Command::Attachment::Create';

sub ARG_TRANSLATIONS { shift->SUPER::ARG_TRANSLATIONS(),  f => 'file'  };

sub usage_msg {
    my $self = shift;
    my ($cmd, $type_and_subcmd) = $self->get_cmd_and_subcmd_names;

    return <<"END_USAGE";
usage: ${cmd}${type_and_subcmd} <record-id> [--file <filename>]
END_USAGE
}

# override args to feed in that ticket's uuid as an argument to the comment
sub run {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    $self->require_uuid;

    $self->set_prop(ticket => $self->uuid);
    $self->SUPER::run(@_);
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

