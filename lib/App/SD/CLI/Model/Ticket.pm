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

=head2 metadata_separator_text

Returns a string of text that goes in the comment denoting the beginning of
uneditable ticket metadata in a string representing a ticket.

Uneditable ticket metadata includes things such as ticket id and
creation date that are useful to display to the user when editing a
ticket but are automatically assigned by sd and are not intended to
be changed manually.

=cut

sub metadata_separator_text {
    'required ticket metadata (changes here will not be saved)'
}

=head2 editable_props_separator_text

Returns a string that denotes the text that goes in the comment denoting the
beginning of prop: value pairs that are updatable in a string representing a
ticket.

=cut

sub editable_props_separator_text { 'edit ticket details below' }

=head2 comment_separator_text

Returns a string that goes in the comment that separates the prop: value lines
from the ticket comment in a string representing a ticket. The ticket comment
will be free text to the end of the new ticket. May contain arbitrary newlines.

=cut

sub comment_separator_text { 'add new ticket comment below' }

=head2 separator_pattern

A pattern that will match on lines that count as section separators
in tickets represented as strings. Separator string text is remembered
as C<$1>.

=cut

sub separator_pattern { qr/^=== (.*) ===$/ }

=head2 create_separator $text

Takes a string and returns it in separator form.

=cut

sub create_separator {
    my $self = shift;
    my $text = shift;

    return "=== $text ===";
}

=head2 comment_pattern

Returns a pattern that will match on lines that count as comments in
tickets represented as strings.

=cut

sub comment_pattern { qr/^\s*#/ }

=head2 create_record_string

Creates a string representing a new record, prefilling default props
and props specified on the command line. Intended to be presented to
the user for editing using L<Prophet::CLI::Command->edit_text>
and then parsed using L</create_record_string>.

=cut

sub create_record_string {
    my $self = shift;
    my $record = $self->_get_record_object;

    my $props_not_to_edit = $record->props_not_to_edit;
    my (@metadata_order, @editable_order);
    my (%metadata_props, %editable_props);

    # separate out user-editable props so we can both show all
    # the props that will be added to the new ticket and prevent
    # users from being able to break things by changing props
    # that shouldn't be changed, such as uuid
    foreach my $prop ($record->props_to_show) {
        if ($prop =~ $props_not_to_edit) {
            unless ($prop eq 'id' or $prop eq 'created') {
                push @metadata_order, $prop;
                # which came first, the chicken or the egg?
                #
                # we don't want to display id/created because they can't by
                # their nature be specified until the ticket is actually
                # created
                $metadata_props{$prop} = undef;
            }
        } else {
            push @editable_order, $prop;
            $editable_props{$prop} = undef;
        }
    }

    # fill in prop defaults
    $record->default_props(\%metadata_props);
    $record->default_props(\%editable_props);

    # fill in props specified on the commandline (overrides defaults)
    if ($self->has_arg('edit')) {
        map { $editable_props{$_} = $self->prop($_) if $self->has_prop($_) } @editable_order;
        $self->delete_arg('edit');
    }

    # make undef values empty strings to avoid interpolation warnings
    # (we can't do this earlier because $record->default_props only
    # overrides undefined props)
    map { $metadata_props{$_} = '' if !defined($metadata_props{$_}) }
        @metadata_order;
    map { $editable_props{$_} = '' if !defined($editable_props{$_}) }
        @editable_order;

    my $metadata_separator = $self->create_separator(metadata_separator_text());
    my $editable_separator = $self->create_separator(editable_props_separator_text());
    my $comment_separator = $self->create_separator(comment_separator_text());

    my $metadata_props_string = join "\n",
                        map { "$_: $metadata_props{$_}" } @metadata_order;
    my $editable_props_string = join "\n",
                        map { "$_: $editable_props{$_}" } @editable_order;

    # glue all the parts together
    my $ticket_string = $metadata_separator . "\n\n" . $metadata_props_string
                    . "\n\n" . $editable_separator . "\n\n" .
                    $editable_props_string . "\n\n" . $comment_separator
                    . "\n";
}

=head2 parse_record_string $str

Takes a string containing a ticket record consisting of prop: value pairs
followed by a separator, followed by an optional comment.

Returns a list of (hashref of prop => value pairs, string contents of comment)
with props with false values filtered out.

=cut

sub parse_record_string {
    my $self = shift;
    my $ticket = shift;

    my @lines = split "\n", $ticket;
    my $last_seen_sep = '';
    my %new_props;
    my $comment = '';

    foreach my $line (@lines) {
        if ($line =~ separator_pattern()) {
            $last_seen_sep = $1;
        } elsif ($line =~ comment_pattern() or
            # skip comments and unchangeable props
            $last_seen_sep eq metadata_separator_text()) {
            next;
        } elsif ($last_seen_sep eq editable_props_separator_text()) {
            # match prop: value pairs. whitespace in between is ignored.
            if ($line =~ m/^([^:]+):\s*(.*)$/) {
                my $prop = $1;
                my $val = $2;
                $new_props{$prop} = $val unless !($val);
            }
        } elsif ($last_seen_sep eq comment_separator_text()) {
            $comment .= $line;
        }
    }

    return \%new_props, $comment;
}

no Moose::Role;

1;

