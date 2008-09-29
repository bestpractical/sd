package App::SD::CLI::Command::Ticket::Update;
use Moose;

extends 'Prophet::CLI::Command::Update';
with 'App::SD::CLI::Model::Ticket';
with 'App::SD::CLI::Command';

# use an editor to edit if no props are specified on the commandline,
# allowing the creation of a new comment in the process
override run => sub {
    my $self = shift;
    $self->require_uuid;

    my $record = $self->_load_record;
    my $props = $record->get_props;

    if (!@{$self->prop_set} || $self->has_arg('edit')) {
        my $ticket_string_to_edit = $self->create_record_string($record);
        my $do_not_edit = $record->props_not_to_edit;

        my $updated = $self->edit_text($ticket_string_to_edit);

        die "Aborted.\n"
            if $updated eq $ticket_string_to_edit; # user didn't change anything

        my ($props_ref, $comment) = $self->parse_record_string($updated);

        no warnings 'uninitialized';

        # set new props but don't add props that didn't change to the changeset
        foreach my $prop (keys %$props_ref) {
            my $val = $props_ref->{$prop};
            $record->set_prop(name => $prop, value => $val)
                unless $val eq $record->prop($prop);
        }

        # if a formerly existing prop was removed from the output, delete it
        foreach my $prop (keys %{$record->get_props}) {
            unless ($prop =~ /$do_not_edit/) {
                $record->delete_prop(name => $prop) if !exists $props_ref->{$prop};
            }
        }

        print 'Updated ticket ' . $record->luid . ' (' . $record->uuid . ")\n";

        $self->add_comment( content => $comment, uuid => $record->uuid )
            if $comment;

    } else {
        super();
    }
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;
