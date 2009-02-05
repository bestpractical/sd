package App::SD::Replica::debbugs::PullEncoder;
use Any::Moose;

use Params::Validate qw(:all);
use Memoize;

has sync_source => (
    isa => 'App::SD::Replica::debbugs',
    is => 'rw',
);

our $DEBUG = $Prophet::Handle::DEBUG;

sub run {
    my $self = shift;
    my %args = validate( @_, {
            # mandatory args go here
            example => 1,
        }
    );

    # TODO: code goes here
}

our %PROP_MAP = (
    remote_prop             => 'sd_prop',
    # ...
}

=head2 translate_prop_names L<Prophet::ChangeSet>

=cut

sub translate_prop_names {
    my $self      = shift;
    my $changeset = shift;

    # ...

    return $changeset;
}

=head2 resolve_user_id_to_email ID

This is only implemented in Hiveminder::PullEncoder; in RT::PullEncoder
it's resolve_user_id_to. What's this for, actually?

=cut

sub resolve_user_id_to_email {
    my $self = shift;
    my $id   = shift;
    return undef unless ($id);

    # ...

    # returns email address mapping to user id
}

memoize 'resolve_user_id_to_email';

=head2 find_matching_tickets QUERY

=cut

sub find_matching_tickets {
    my $self = shift;
    my ($query) = validate_pos(@_, 1);
    return $self->sync_source->rt->search( type => 'ticket', query => $query );
}

=head2 find_matching_transactions TASK, START

=cut

sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { task => 1, starting_transaction => 1 } );

    # ...

    return \@matched;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
