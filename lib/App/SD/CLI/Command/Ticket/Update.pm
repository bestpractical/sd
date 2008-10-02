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

        TRY_AGAIN:
        my $updated = $self->edit_text($ticket_string_to_edit);

        die "Aborted.\n"
            if $updated eq $ticket_string_to_edit; # user didn't change anything

        my ($props_ref, $comment) = $self->parse_record_string($updated);

        no warnings 'uninitialized';

        # if a formerly existing prop was removed from the output, delete it
        # (deleting is currently the equivalent of setting to '', and
        # we want to do this all in one changeset)
        foreach my $prop (keys %{$record->get_props}) {
            unless ($prop =~ $do_not_edit) {
                $props_ref->{$prop} = '' if !exists $props_ref->{$prop};
            }
        }

        # don't add props that didn't change to the changeset
        foreach my $prop (keys %$props_ref) {
            delete $props_ref->{$prop}
                if $props_ref->{$prop} eq $record->prop($prop);
        }

        # set the new props
        my $error;
        {
            local $@;
            eval { $record->set_props( props => $props_ref ) }
                or $error = $@ || "Something went wrong!";
        }
        if ( $error ) {
            print STDERR "Couldn't update the record, error:\n\n", $error, "\n";
            die "Aborted.\n" unless $self->prompt_Yn( "Want to return back to editing?" );

            ($ticket_string_to_edit, $error) = ($updated, '');
            goto TRY_AGAIN;
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
