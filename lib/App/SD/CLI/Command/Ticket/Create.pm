package App::SD::CLI::Command::Ticket::Create;
use Moose;

use App::SD::CLI::Command::Ticket::Comment::Create qw(new);

extends 'Prophet::CLI::Command::Create';
with 'App::SD::CLI::Model::Ticket';
with 'App::SD::CLI::Command';

# we want to launch an $EDITOR window to grab props and a comment if no
# props are specified on the commandline
override run => sub {
    my $self = shift;
    my $record = $self->_get_record_class;
    my @prop_set = $self->prop_set;

    # only invoke editor if no props specified on the commandline or edit arg
    # specified
    if (!@prop_set || $self->has_arg('edit')) {
        my @props = grep {!/^id$/} $record->props_to_show;

        my %prefill_props;
        # these props must exist in the hash, even if they have no value
        map { $prefill_props{$_} = undef } @props;
        # set default props
        $record->default_props(\%prefill_props);
        if ($self->has_arg('edit')) {
            # override with props specified on the commandline
            map { $prefill_props{$_} = $self->prop($_) if $self->has_prop($_) } @props;
            $self->delete_arg('edit');
        }
        # undef values are noisy later when we want to interpolate the hash
        map { $prefill_props{$_} = '' if !defined($prefill_props{$_}) } @props;

        my $footer = comment_separator();

        my $ticket = $self->get_content( type => 'ticket', default_edit => 1,
                                         prefill_props => \%prefill_props,
                                         props_order => \@props,
                                         footer => $footer,
                                       );

        die "Aborted.\n"
            if length($ticket) == 0;

        (my $props_ref, my $comment) = $self->parse_record($ticket);

        foreach my $prop (keys %$props_ref) {
            $self->set_prop($prop => $props_ref->{$prop})
                unless $prop eq 'id'; # don't let users create ids
        }

        super();

        # retrieve the created record from the superclass
        $record = $self->record();

        if ($comment) {
            my $args = { uuid => $record->uuid(),
                         content => $comment,
                       };
            $self->cli->change_attributes( args => $args );
            my $command = App::SD::CLI::Command::Ticket::Comment::Create->new(
                cli => $self->cli,
                type => 'comment',
            );
            $command->run();
        }
    } else {
        super();
    }
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;
