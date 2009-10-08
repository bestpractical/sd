package App::SD::Replica::rt;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use File::Temp 'tempdir';
use Memoize;

use constant scheme => 'rt';
use constant pull_encoder => 'App::SD::Replica::rt::PullEncoder';
use constant push_encoder => 'App::SD::Replica::rt::PushEncoder';


use Prophet::ChangeSet;

has rt => ( isa => 'RT::Client::REST', is => 'rw');
has remote_url => ( isa => 'Str', is => 'rw');
has rt_queue => ( isa => 'Str', is => 'rw');
has query => ( isa => 'Str', is => 'rw');
has rt_username => (isa => 'Str', is => 'rw');

sub BUILD {
    my $self = shift;

    # Require rather than use to defer load
    eval {
        require RT::Client::REST;
        require RT::Client::REST::User;
        require RT::Client::REST::Ticket;
    };
    if ($@) {
        warn $@ if $ENV{PROPHET_DEBUG};
        die "RT::Client::REST is required to sync with RT foreign replicas.\n";
    }

    my ( $server, $type, $query ) = $self->{url} =~ m{^rt:(https?://.*?)\|(.*?)\|(.*)$}
        or die "Can't parse RT server spec. Expected 'rt:http://example.com|QUEUE|QUERY'.\n"
                ."Try: 'rt:http://example.com/|General|'.\n";
    my $uri = URI->new($server);
    my ( $username, $password );
    if ( my $auth = $uri->userinfo ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }
    $self->remote_url($uri->as_string);
    $self->rt_queue($type);
    $self->query( ( $query ?  "($query) AND " :"") . " Queue = '$type'" );
    $self->rt( RT::Client::REST->new( server => $server ) );

    ( $username, $password )
        = $self->prompt_for_login(
            uri      => $uri,
            username => $username,
        ) unless $password;

    $self->rt_username($username);

    eval {
        $self->rt->login( username => $username, password => $password );
    };
    if ($@) {
        die "Login to '$server' with username '$username' failed!\n"
            ."Error was: $@.\n";
    }
}

sub foreign_username { return shift->rt_username(@_)}
  
sub get_txn_list_by_date {
    my $self   = shift;
    my $ticket = shift;
    my @txns   = map {
        my $txn_created_dt = App::SD::Util::string_to_datetime( $_->created );
        unless ($txn_created_dt) {
            die "Couldn't parse '" . $_->created . "' as a timestamp";
        }
        my $txn_created = $txn_created_dt->epoch;

        return { id => $_->id, creator => $_->creator, created => $txn_created }
        }

        sort { $b->id <=> $a->id }
        RT::Client::REST::Ticket->new( rt => $self->rt, id => $ticket )->transactions->get_iterator->();
    return @txns;
}

=head2 uuid

Return the replica's UUID

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_for_url( join( '/', $self->remote_url, $self->query ) );

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

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
