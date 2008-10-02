package App::SD::CLI::Command::Ticket::Create;
use Moose;

extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::Ticket';
with 'App::SD::CLI::Command';

# we want to launch an $EDITOR window to grab props and a comment if no
# props are specified on the commandline
override run => sub {
    my $self = shift;
    my @prop_set = $self->prop_set;
    my $record = $self->_get_record_object;

    # only invoke editor if no props specified on the commandline or edit arg
    # specified
    if (!@prop_set || $self->has_arg('edit')) {
        my $ticket_string_to_edit = $self->create_record_string();

        TRY_AGAIN:
        my $ticket = $self->edit_text($ticket_string_to_edit);

        die "Aborted.\n"
            if $ticket eq $ticket_string_to_edit; # user didn't change anything

        (my $props_ref, my $comment) = $self->parse_record_string($ticket);

        foreach my $prop (keys %$props_ref) {
            $self->set_prop($prop => $props_ref->{$prop});
        }

        my $error;
        {
            local $@;
            eval { super(); } or $error = $@ || "Something went wrong!";
        }
        if ( $error ) {
            print STDERR "Couldn't create a record, error:\n\n", $error, "\n";
            die "Aborted.\n" unless $self->prompt_Yn( "Want to return back to editing?" );

            ($ticket_string_to_edit, $error) = ($ticket, '');
            goto TRY_AGAIN;
        }

        # retrieve the created record from the superclass
        $record = $self->record();

        $self->add_comment( content => $comment, uuid => $record->uuid )
            if $comment;

    } else {
        super();
    }
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;
