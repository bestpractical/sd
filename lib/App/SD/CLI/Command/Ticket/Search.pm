package App::SD::CLI::Command::Ticket::Search;
use Moose;
extends 'Prophet::CLI::Command::Search';

# frob the sort routine before running prophet's search command
before run => sub {
    my $self = shift;

    # sort output by created date if user specifies --sort
    if ($self->has_arg('sort')) {
        # some records might not have creation dates
        no warnings 'uninitialized';
        # sort by creation date
        my $sort_routine = sub {
            my @records = @_;
            return (sort { $a->prop('created') cmp $b->prop('created') } @records);
        };
        $self->sort_routine($sort_routine);
    }
};

# implicit status != closed
before get_search_callback => sub {
    my $self = shift;

    # if they specify a specific status then don't limit on status
    # or, if they specify --all, then don't limit on status
    unless ($self->has_prop('status') || $self->has_arg('all')) {
        $self->add_to_prop_set({
            prop  => 'status',
            cmp   => '!=',
            value => 'closed',
        });
    }
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

