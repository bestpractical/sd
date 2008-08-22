package App::SD::Replica::rt;
use Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use Path::Class;
use File::Temp 'tempdir';
use Memoize;

use constant scheme => 'rt';

use Prophet::ChangeSet;

has rt => ( isa => 'RT::Client::REST', is => 'rw');
has remote_url => ( isa => 'Str', is => 'rw');
has rt_queue => ( isa => 'Str', is => 'rw');
has rt_query => ( isa => 'Str', is => 'rw');

# XXX: this should be called from superclass, or better, have individual attributes have their own builders.

around 'new' => sub {
    my ($next, $self, @args) = @_;
    my $ret = $self->$next(@args);
    $ret->setup;
    return $ret;
};

sub setup {
    my $self = shift;

    # Require rather than use to defer load
    require RT::Client::REST;
    require RT::Client::REST::User;
    require RT::Client::REST::Ticket;

    my ( $server, $type, $query ) = $self->{url} =~ m/^rt:(.*?)\|(.*?)\|(.*)$/
        or die "Can't parse RT server spec. Expected rt:http://example.com|QUEUE|QUERY. Try: rt:http://example.com/|General|";
    my $uri = URI->new($server);
    my ( $username, $password );
    if ( my $auth = $uri->userinfo ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }
    $self->remote_url($uri->as_string);
    $self->rt_queue($type);
    $self->rt_query( ( $query ?  "($query) AND " :"") . " Queue = '$type'" );
    $self->rt( RT::Client::REST->new( server => $server ) );

    ( $username, $password ) = $self->prompt_for_login( $uri, $username )
        unless $password;

    $self->rt->login( username => $username, password => $password );
}

sub record_pushed_transactions {
    my $self = shift;
    my %args = validate( @_,
        { ticket => 1, changeset => { isa => 'Prophet::ChangeSet' } } );

    for my $txn (
        reverse RT::Client::REST::Ticket->new(
            rt => $self->rt,
            id => $args{'ticket'}
        )->transactions->get_iterator->()
        )
    {
        last
            if $txn->id <= $self->last_changeset_from_source(
                    $args{changeset}->original_source_uuid
            );
        $self->record_pushed_transaction(
            transaction => $txn->id,
            changeset   => $args{'changeset'}
        );
    }
}
sub record_pushed_ticket {
    my $self = shift;
    my %args = validate(
        @_,
        {   uuid      => 1,
            remote_id => 1
        }
    );
    $self->_set_uuid_for_remote_id(%args);
    $self->_set_remote_id_for_uuid(%args);
}

sub _integrate_change {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    require App::SD::Replica::rt::PushEncoder;
    my $recoder = App::SD::Replica::rt::PushEncoder->new( { sync_source => $self } );
    $recoder->integrate_change($change,$changeset);
}

=head2 uuid

Return the replica SVN repository's UUID

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_for_url( join( '/', $self->remote_url, $self->rt_query ) );

}

sub traverse_changesets {
    my $self = shift;
    my %args = validate( @_,
        {   after    => 1,
            callback => 1,
        }
    );

    require App::SD::Replica::rt::PullEncoder;
    my $recoder = App::SD::Replica::rt::PullEncoder->new( { sync_source => $self } );
    $recoder->run( query => $self->rt_query, after => $args{'after'}, callback => $args{'callback'});

}

sub remote_uri_path_for_id {
    my $self = shift;
    my $id = shift;
    return "/ticket/".$id;
}


=head1 NOTES ON PUSH

If the remote storage (RT) can not represent a whole changeset along with the prophet changeset uuid, then we need to 
create a seperate locally(?) stored map of:
    remote-subchangeset-identifier to changeset uuid.
    remote id to prophet record uuid
    

For each sync of the same remote source (RT), we need a unique prophet database domain.

if clkao syncs from RT, jesse can sync with clkao but not with RT directly with the same database.


Push to rt algorithm

apply a single changeset that's part of the push:
    - for each record in that changeset:
        - pull the record's txn list from the server
        - for each txn we don't know we've already seen, look at it
            - if it is from the changeset we just pushed, then
                store the id of the new transaction and originating uuid in the push-ticket store.
                    - does that let us specify individual txns? or is it a high-water mark?
             - if it is _not_ from the changeset we just pushed, then 
                do we just ignore it?
                how do we mark an out-of-order transaction as not-pulled?
                


Changesets we want to push from SD to RT and how they map

    
what do we do with cfs rt doesn't know about?



SD::Source::RT->recode_ticket



=cut

=head2 setup


=cut

__PACKAGE__->meta->make_immutable;
no Moose;

1;
