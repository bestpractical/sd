package App::SD::Replica::debbugs;
use Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use Memoize;

use Prophet::ChangeSet;

use constant scheme => 'debbugs';

# FIXME: what should this actually be?
has debbugs => ( isa => 'Net::Debbugs', is => 'rw');
has remote_url => ( isa => 'Str', is => 'rw');
has debbugs_query => ( isa => 'Str', is => 'rw');

sub setup {
    my $self = shift;

    # require any specific libs needed by this foreign replica

    # parse the given url
    # my ($foo, $bar, $baz) = $self->{url} =~ m/regex-here/

    # ...
}

sub record_pushed_transactions {}

# XXX record_pushed_tikcet should go up to the base class

sub record_pushed_ticket {
    my $self = shift;
    my %args = validate(
        @_,
        {   uuid      => 1,
            remote_id => 1,
        }
    );
    $self->_set_uuid_for_remote_id(%args);
    $self->_set_remote_id_for_uuid(%args);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
