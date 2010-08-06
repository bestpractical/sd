package App::SD::Replica::debbugs;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Memoize;

use constant scheme => 'debbugs';
use constant pull_encoder => 'App::SD::Replica::debbugs::PullEncoder';
use constant push_encoder => 'App::SD::Replica::debbugs::PushEncoder';

has debbugs    => ( isa => 'SOAP::Lite', is   => 'rw' );
has remote_url => ( isa => 'Str', is          => 'rw');
has query      => ( isa => 'HashRef', is      => 'rw');

=head2 BUILD

Open a connection to the source identified by C<$self->{url}>.

=cut

sub BUILD {
    my $self = shift;

    # require any specific libs needed by this foreign replica
    require SOAP::Lite;

    # parse the given url / query
    my ($server, $query) = $self->{url} =~ m/^debbugs:(.*?)\|(.*)$/;
    print "\n$server\n";
    print $query . "\n";
    ($server, $query) = $self->{url} =~ m/^debbugs:(.*?)\|(.*)$/
        or die "Can't parse debbugs query. "
            . "Expected debbugs:http://bugs.example.org|QUERY.\n";
    # QUERY looks like: submitter=spang@mit.edu,owner=spang@mit.edu

    # $self->remote_url( "$server/cgi-bin/soap.cgi" );
    $self->remote_url( $server );

    # XXX TODO make this more robust (quoted values etc)
    my %query_hash = split /=|,/, $query;
    # use Data::Dump qw(pp);
    # pp %query_hash;

    # queries to support: all things that are passed to get_status, get_newest
    $self->query( \%query_hash );

    # debbugs sync does not require auth
    $self->debbugs(SOAP::Lite->uri('Debbugs/SOAP')->proxy($self->remote_url));
}

sub record_pushed_transactions {}

=head2 uuid

Return the replica's UUID
XXX cut-n-paste directly from RT sync, should move to ForeignReplica?

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_for_url( join( '/', $self->remote_url, $self->query ) );

}

=head2 remote_uri_path_for_id

=cut

sub remote_uri_path_for_id {
    my ($self, $id) = @_;
    return "/cgi-bin/bugreport.cgi?bug=$id";
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
