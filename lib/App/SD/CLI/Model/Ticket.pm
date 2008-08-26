package App::SD::CLI::Model::Ticket;
use Moose::Role;
use Params::Validate qw(:all);
use constant record_class => 'App::SD::Model::Ticket';


=head2 add_comment content => str, uuid => str

A convenience method that takes a content string and a ticket uuid and creates
a new comment record, for use in other commands (such as ticket create
and ticket update).

=cut

sub add_comment {
    my $self = shift;
    validate(@_, { content => 1, uuid => 1 } );
    my %args = @_;

    require App::SD::CLI::Command::Ticket::Comment::Create;

    $self->context->mutate_attributes( args => \%args );
    my $command = App::SD::CLI::Command::Ticket::Comment::Create->new(
        uuid => $args{uuid},
        cli => $self->cli,
        context => $self->context,
        type => 'comment',
    );
    $command->run();
}


=head2 comment_separator

Returns a string that separates the prop: value lines from the comment,
which will be free text to the end of the new ticket. May contain
arbitrary newlines.

=cut

sub comment_separator { "\n\n=== add new ticket comment below ===\n"; }

=head2 parse_record $str

Takes a string containing a ticket record consisting of prop: value pairs
followed by a separator, followed by an optional comment.

Returns a list of (hashref of prop => value pairs, string contents of comment)
with props with false values filtered out.

=cut

sub parse_record {
    my $self = shift;
    my $ticket = shift;

    my %props;
    my ($new_props, $comment) = split comment_separator(), $ticket;
    my @lines = split "\n", $new_props;
    foreach my $line (@lines) {
        # match prop: value pairs. whitespace in between is ignored.
        if ($line =~ m/^([^:]+):\s*(.*)$/) {
            my $prop = $1;
            my $val = $2;
            $props{$prop} = $val unless !($val);
        }
    }
    return \%props, $comment;
}

no Moose::Role;

1;

