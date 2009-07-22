package App::SD::CLI::Command::Ticket::Comment::Update;
use Any::Moose;

extends 'Prophet::CLI::Command::Update';

override run => sub {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    $self->require_uuid;

    my $record = $self->_load_record;
    my @prop_set = $self->prop_set;

    # we don't want to do prop: value editing by default for comments since
    # it's just a blob of text
    if (!@prop_set || $self->has_arg('edit')) {
        my $updated_comment = $self->edit_text($record->prop('content'));
        $record->set_prop(name => 'content', value => $updated_comment);
        print "Updated comment " . $record->luid . " (" . $record->uuid . ")\n";
    } else {
        super();
    }
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
