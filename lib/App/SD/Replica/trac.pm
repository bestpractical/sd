package App::SD::Replica::trac;
use Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use Path::Class;
use File::Temp 'tempdir';
use Memoize;

use constant scheme => 'trac';
use constant pull_encoder => 'App::SD::Replica::trac::PullEncoder';
use constant push_encoder => 'App::SD::Replica::trac::PushEncoder';


use Prophet::ChangeSet;

has trac => ( isa => 'Net::Trac::Connection', is => 'rw');
has remote_url => ( isa => 'Str', is => 'rw');


sub BUILD {
    my $self = shift;

    # Require rather than use to defer load
    require Net::Trac;

    my ( $server, $type, $query ) = $self->{url} =~ m/^trac:(.*?)$/
        or die
        "Can't parse Trac server spec. Expected trac:http://example.com";
    my $uri = URI->new($server);
    my ( $username, $password );
    if ( my $auth = $uri->userinfo ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }
    $self->remote_url( $uri->as_string );

    #( $username, $password ) = $self->prompt_for_login( $uri, $username ) unless $password;
    $self->trac(
        Net::Trac::Connection->new(
            url      => $self->remote_url,
            user     => 'jesse',#$username,
            password => 'iron' #$password
        )
    );
    $self->trac->ensure_logged_in;
}

sub record_pushed_transactions {
    my $self = shift;
    my %args = validate( @_,
        { ticket => 1, changeset => { isa => 'Prophet::ChangeSet' } } );

    # walk through every transaction on the ticket, starting with the latest
    for my $txn ( 'find all the transactions pushed upstream') {

        # if the transaction id is older than the id of the last changeset
        # we got from the original source of this changeset, we're done
        last if $txn->id <= $self->last_changeset_from_source(
                    $args{changeset}->original_source_uuid
            );

        # if the transaction from RT is more recent than the most recent
        # transaction we got from the original source of the changeset
        # then we should record that we sent that transaction upstream
        # XXX TODO - THIS IS WRONG - we should only be recording transactions we pushed
        $self->record_pushed_transaction(
            transaction => $txn->id,
            changeset   => $args{'changeset'},
            record      => $args{'ticket'}
        );
    }
}


=head2 uuid

Return the replica's UUID

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_for_url( $self->remote_url);
}


sub remote_uri_path_for_comment {
    my $self = shift;
    my $id = shift;
    return "/comment/".$id;
}

sub remote_uri_path_for_id {
    my $self = shift;
    my $id = shift;
    return "/ticket/".$id;
}


__PACKAGE__->meta->make_immutable;
no Moose;

1;
