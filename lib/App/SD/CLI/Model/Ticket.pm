package App::SD::CLI::Model::Ticket;
use Any::Moose 'Role';
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

=head2 metadata_separator

A string of text that goes in the comment denoting the beginning of
immutable ticket metadata in a string representing a ticket.

Immutable ticket metadata includes things such as ticket id and
creation date that are useful to display to the user when editing a
ticket but are automatically assigned by sd and are not intended to
be changed manually.

=cut

use constant metadata_separator => 'required ticket metadata (changes here will not be saved)';
use constant mutable_props_separator => 'edit ticket details below';
use constant comment_separator => 'add new ticket comment below';

=head2 create_record_template [ RECORD ]

Creates a string representing a new record, prefilling default props
and props specified on the command line. Intended to be presented to
the user for editing using L<Prophet::CLI::TextEditorCommand->try_to_edit>
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
    my ( @metadata_order,  @mutable_order );
    my ( %immutable_props, %mutable_props );

    # separate out user-editable props so we can both show all
    # the props that will be added to the new ticket and prevent
    # users from being able to break things by changing props
    # that shouldn't be changed, such as uuid
    #
    # filter out props we don't want to present for editing
    my %do_not_edit = map { $_ => 1 } @do_not_edit;

    for my $prop ( $record->props_to_show(
            # only call props_to_show with --verbose if we're in an update
            # because new tickets have no declared props
            { 'verbose' => ($self->has_arg('all-props') && $update),
              update => $update } ) ) {
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
            push @mutable_order, $prop;
            $mutable_props{$prop} = $update ? $record->prop($prop) : undef;
        }
    }

    # fill in prop defaults if we're creating a new ticket
    if ( !$update ) {
        $record->default_props( \%immutable_props );
        $record->default_props( \%mutable_props );
    }

    # fill in props specified on the commandline (overrides defaults)
    if ( $self->has_arg('edit') ) {
        map { $mutable_props{$_} = $self->prop($_) if $self->has_prop($_) }
            @mutable_order;
        $self->delete_arg('edit');
    }

    my $immutable_props_string = $self->_build_kv_pairs(
        order => \@metadata_order,
        data  => \%immutable_props,
        verbose => $self->has_arg('verbose'),
        record => $record,
    );

    my $mutable_props_string = $self->_build_kv_pairs(
        order => \@mutable_order,
        data  => \%mutable_props,
        verbose => $self->has_arg('verbose'),
        record => $record,
    );

    # glue all the parts together
    return join(
        "\n",

        $self->build_template_section(
            header => metadata_separator,
            data   => $immutable_props_string
        ),

        $self->build_template_section(
            header => mutable_props_separator,
            data   => $mutable_props_string
        ),
        $self->build_template_section(
            header => comment_separator,
            data   => ''
            )

    );
}

sub _build_kv_pairs {
    my $self = shift;
    my %args = validate (@_, { order => 1, data => 1,
                               verbose => 1, record => 1 });

    my $string = '';
    for my $prop ( @{$args{order}}) {
        # if called with --verbose, we print descriptions and valid values for
        # props (if they exist)
        if ( $args{verbose} ) {
            if ( my $desc = $self->app_handle->setting( label => 'prop_descriptions' )->get()->[0]->{$prop} ) {
                $string .= '# '.$desc."\n";
            }
            if ( ($args{record}->recommended_values_for_prop($prop))[0] ) {
                my @valid_values =
                    $args{record}->recommended_values_for_prop($prop);
                $string .= "# valid values for $prop: ".
                    join(', ', @valid_values)."\n";
            }
        }
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
        if ($line =~ $self->separator_pattern) {
            $last_seen_sep = $1;
        } elsif ($line =~ $self->comment_pattern) {
            # skip comments 
            next;
        } elsif ( $last_seen_sep eq metadata_separator) {
            # skip unchangeable props
            next;
        } elsif ($last_seen_sep eq mutable_props_separator) {
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

no Any::Moose;

1;

