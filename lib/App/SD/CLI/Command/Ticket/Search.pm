package App::SD::CLI::Command::Ticket::Search;
use Moose;
extends 'Prophet::CLI::Command::Search';
with 'App::SD::CLI::Command';

# frob the sort routine before running prophet's search command
before run => sub {
    my $self = shift;

    # sort output by created date if user specifies --sort
    if ($self->has_arg('sort')) {
        # some records might not have creation dates
        no warnings 'uninitialized';
        $self->sort_routine( sub {
                    my $records = shift;
                    return $self->sort_by_creation_date($records) } );
    }
};

# implicit status != closed
sub default_match {
    my $self = shift;
    my $ticket = shift;

    return 0 if $ticket->prop('status') eq 'closed';
    return 1;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

