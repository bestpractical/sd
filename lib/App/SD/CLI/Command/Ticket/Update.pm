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
        my $do_not_edit = $record->props_not_to_edit;

        my @show_props;
        if ($record->can('props_to_show')) {
            @show_props = $record->props_to_show;
        } else {
            @show_props = sort keys %$props;
        }

        # props we want to show for editing
        my %prefill_props = %{$record->get_props};
        map { $prefill_props{$_} = '' if !exists $prefill_props{$_} } @show_props;

        # add any other defined props onto the end of the ordering and remove
        # unwanted props
        my %tmp;
        map { $tmp{$_} = 1 } @show_props;
        map { push @show_props, $_ unless exists $tmp{$_} } keys %prefill_props;
        @show_props = grep !/$do_not_edit/, @show_props;

        my $updated = $self->get_content( type => 'ticket', default_edit => 1,
                                          prefill_props => \%prefill_props,
                                          props_order => \@show_props,
                                          footer => comment_separator(),
                                      );

        die "Aborted.\n"
            if length($updated) == 0;

        my ($props_ref, $comment) = $self->parse_record($updated);

        no warnings 'uninitialized';

        foreach my $prop (keys %$props_ref) {
            my $val = $props_ref->{$prop};
            $record->set_prop(name => $prop, value => $val) unless
                ($prop =~ /$do_not_edit/ or $val eq $prefill_props{$prop});
        }

        # if a formerly existing prop was removed from the output, delete it
        foreach my $prop (keys %{$record->get_props}) {
            unless ($prop =~ /$do_not_edit/) {
                $record->delete_prop(name => $prop) if !exists $props_ref->{$prop};
            }
        }

        print 'Updated ticket ' . $record->luid . ' (' . $record->uuid . ")\n";

        $self->create_new_comment( content => $comment, uuid => $record->uuid )
            if $comment;

    } else {
        super();
    }
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;
