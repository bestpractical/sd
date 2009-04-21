package App::SD::Replica::debbugs;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use Memoize;

use Prophet::ChangeSet;

use constant scheme => 'debbugs';

# FIXME: what should this actually be?
has debbugs => ( isa => 'Net::Debbugs', is => 'rw');
has remote_url => ( isa => 'Str', is => 'rw');
has debbugs_query => ( isa => 'Str', is => 'rw');

=head2 BUILD

Open a connection to the source identified by C<$self->{url}>.

=cut

sub BUILD {
    my $self = shift;

    # require any specific libs needed by this foreign replica

    # parse the given url
    # my ($foo, $bar, $baz) = $self->{url} =~ m/regex-here/

    # ...
}

sub record_pushed_transactions {}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
