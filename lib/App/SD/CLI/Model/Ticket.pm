package App::SD::CLI::Model::Ticket;
use Moose::Role;
use Params::Validate qw(:all);
use constant record_class => 'App::SD::Model::Ticket';


=head2 separator_pattern

A pattern that will match on lines that count as section separators
in tickets represented as strings. Separator string text is remembered
as C<$1>.

=cut

use constant separator_pattern => qr/^=== (.*) ===$/;
use constant comment_pattern => qr/^\s*#/;



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

=head2 metadata_separator

Returns a string of text that goes in the comment denoting the beginning of
uneditable ticket metadata in a string representing a ticket.

Uneditable ticket metadata includes things such as ticket id and
creation date that are useful to display to the user when editing a
ticket but are automatically assigned by sd and are not intended to
be changed manually.

=cut

use constant metadata_separator => 'required ticket metadata (changes here will not be saved)';
use constant editable_props_separator => 'edit ticket details below';
use constant comment_separator => 'add new ticket comment below';

=head2 _build_separator $text

Takes a string and returns it in separator form.

=cut

sub _build_separator {
    my $self = shift;
    my $text = shift;

    return "=== $text ===";
}


=head2 create_record_template RECORD

Creates a string representing a new record, prefilling default props
and props specified on the command line. Intended to be presented to
the user for editing using L<Prophet::CLI::Command->edit>
and then parsed using L</parse_record_template>.

If RECORD is given, then we are updating that record rather than
creating a new one, and the ticket string will be created from its
props rather than prop defaults.

=cut

sub create_record_template {
    my $self   = shift;
    my $record = shift;
    my $update;

    if ($record) { $update = 1 }
    else {

        $record = $self->_get_record_object;
        $update = 0;
    }

    my @do_not_edit = $record->immutable_props;
    my ( @metadata_order,  @editable_order );
    my ( %immutable_props, %editable_props );

    # separate out user-editable props so we can both show all
    # the props that will be added to the new ticket and prevent
    # users from being able to break things by changing props
    # that shouldn't be changed, such as uuid
    #
    # filter out props we don't want to present for editing
    my %do_not_edit = map { $_ => 1 } @do_not_edit;
   
    
    for my $prop ( $record->props_to_show ) {
        if ( $do_not_edit{$prop}) {
            if ( $prop eq 'id' && $update ) {

                # id isn't a *real* prop, so we have to mess with it some more
                push @metadata_order, $prop;
                $immutable_props{$prop}
                    = $record->luid . ' (' . $record->uuid . ")";
            } elsif ( !( ( $prop eq 'id' or $prop eq 'created' ) && !$update ) )
            {
                push @metadata_order, $prop;

                # which came first, the chicken or the egg?
                #
                # we don't want to display id/created for ticket creates
                # because they can't by their nature be specified until the
                # ticket is actually created
                $immutable_props{$prop}
                    = $update ? $record->prop($prop) : undef;
            }
        } else {
            push @editable_order, $prop;
            $editable_props{$prop} = $update ? $record->prop($prop) : undef;
        }
    }

    # fill in prop defaults if we're creating a new ticket
    if ( !$update ) {
        $record->default_props( \%immutable_props );
        $record->default_props( \%editable_props );
    }

    # fill in props specified on the commandline (overrides defaults)
    if ( $self->has_arg('edit') ) {
        map { $editable_props{$_} = $self->prop($_) if $self->has_prop($_) }
            @editable_order;
        $self->delete_arg('edit');
    }

    my $immutable_props_string = $self->_build_kv_pairs(
        order => \@metadata_order,
        data  => \%immutable_props
    );
    my $editable_props_string = $self->_build_kv_pairs(
        order => \@editable_order,
        data  => \%editable_props
    );

    # glue all the parts together
    return join(
        "\n",

        $self->_build_template_section(
            header => metadata_separator,
            data   => $immutable_props_string
        ),

        $self->_build_template_section(
            header => editable_props_separator,
            data   => $editable_props_string
        ),
        $self->_build_template_section(
            header => comment_separator,
            data   => ''
            )

    );
}

sub _build_template_section {
    my $self = shift;
    my %args = validate (@_, { header => 1, data => 0 });
    return $self->_build_separator($args{'header'}) ."\n\n". ( $args{data} || '');
}

sub _build_kv_pairs {
    my $self = shift;
    my %args = validate (@_, { order => 1, data => 1 });

    my $string = '';
    for my $prop ( @{$args{order}}) {
        $string .= "$prop: ".($args{data}->{$prop} ||'') ."\n";
    }
    return $string;
}



=head2 parse_record_template $str

Takes a string containing a ticket record consisting of prop: value pairs
followed by a separator, followed by an optional comment.

Returns a list of (hashref of prop => value pairs, string contents of comment)
with props with false values filtered out.

=cut

sub parse_record_template {
    my $self = shift;
    my $ticket = shift;

    my @lines = split "\n", $ticket;
    my $last_seen_sep = '';
    my %new_props;
    my $comment = '';

    for my $line (@lines) {
        if ($line =~ separator_pattern) {
            $last_seen_sep = $1;
        } elsif ($line =~ comment_pattern) {
            # skip comments 
            next;
        } elsif ( $last_seen_sep eq metadata_separator) {
            # skip unchangeable props
            next;
        } elsif ($last_seen_sep eq editable_props_separator) {
            # match prop: value pairs. whitespace in between is ignored.
            if ($line =~ m/^([^:]+):\s*(.*)$/) {
                my $prop = $1;
                my $val = $2;
                $new_props{$prop} = $val unless !($val);
            }
        } elsif ($last_seen_sep eq comment_separator) {
            $comment .= $line . "\n";
        } else {
            # Throw away the section 
        }
    }

    return \%new_props, $comment;
}

no Moose::Role;

1;

