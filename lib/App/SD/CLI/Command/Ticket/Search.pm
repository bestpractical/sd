package App::SD::CLI::Command::Ticket::Search;
use Moose;
extends 'Prophet::CLI::Command::Search';
with 'App::SD::CLI::Command';

# frob the sort routine before running prophet's search command
before run => sub {
    my $self = shift;

    # sort output by created date if user specifies --sort
    if ( $self->has_arg('sort') ) {

        # some records might not have creation dates
        no warnings 'uninitialized';
        $self->sort_routine(
            sub {
                my $records = shift;
                return $self->sort_by_prop( created => $records );
            }
        );
    }

    if ( $self->has_arg('group') ) {
        $self->group_routine(
            sub {
                my $records = shift;
                my $groups =  $self->group_by_prop( $self->arg('group') => $records );
                if ($self->arg('group') eq 'milestone') {
                    my $order = $self->app_handle->setting( label => 'milestones' )->get();
                    my %group_hash = map { $_->{'label'} => $_->{'records'} } @$groups;
                    my $sorted_groups = [ map { 
                                
                                    { label => $_, records => (delete $group_hash{$_} || []) }

                                } @$order ];
                    return [@$sorted_groups, (map { {label => $_, records => $group_hash{$_}}} keys %group_hash )];
                }
                return $groups;
            }
        );
    }
};

# implicit status != closed
sub default_match {
    my $self = shift;
    my $ticket = shift;

    return 1 if $ticket->prop('status') ne 'closed';
    return 0;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

