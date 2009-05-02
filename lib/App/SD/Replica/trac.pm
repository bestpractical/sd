package App::SD::Replica::trac;
use Any::Moose;
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

    ( $username, $password ) = $self->prompt_for_login( $uri, $username ) unless $password;
    $self->trac(
        Net::Trac::Connection->new(
            url      => $self->remote_url,
            user     => $username,
            password => $password
        )
    );
    $self->trac->ensure_logged_in;
}

sub record_pushed_transactions {
    my $self = shift;
    my %args = validate( @_,
        { ticket => 1, changeset => { isa => 'Prophet::ChangeSet' }, start_time => 1} );


    my $earliest_valid_txn_date;
    
    # walk through every transaction on the ticket, starting with the latest
    my $ticket = Net::Trac::Ticket->new( connection => $self->trac);
    $ticket->load($args{ticket});

    for my $txn ( sort {$b->date <=> $a->date }  @{$ticket->history->entries}) {

        warn "Recording that we pushed ".$ticket->id. " " .$txn->date;

        my $oldest_changeset_for_ticket = $self->app_handle->handle->last_changeset_from_source( $args{changeset}->original_source_uuid);

        # walk backwards through all transactions on the ticket we just updated
        # Skip any transaction where the remote user isn't me, this might include any transaction
        # RT created with a scrip on your behalf

        next unless $txn->author eq $self->trac->user;
        # XXX - are we always decoding txn author correctly?

        # get the completion time _after_ we do our next round trip to rt to try to make sure
        # a bit of lag doesn't skew us to the wrong side of a 1s boundary
        my $txn_created_dt = $txn->date;
        unless($txn_created_dt) {
            die $args{ticket}. " - Couldn't parse '".$txn->created."' as a timestamp";
        }
        my $txn_created = $txn_created_dt->epoch;


        # skip any transaction created more than 5 seconds before the push started.
        if (!$earliest_valid_txn_date){
            my $change_window =  time() - $args{start_time};
            # I can't think of any reason that number shouldn't be 1, but clocks are fickle
            $earliest_valid_txn_date = $txn_created - ($change_window + 5); 
        }      

        last if $txn_created < $earliest_valid_txn_date;

        # if the transaction id is older than the id of the last changeset
        # we got from the original source of this changeset, we're done
        last if $txn_created <= $oldest_changeset_for_ticket;

        # if the transaction from trac is more recent than the most recent
        # transaction we got from the original source of the changeset
        # then we should record that we sent that transaction upstream

        $self->record_pushed_transaction(
            transaction => $txn_created,
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
no Any::Moose;

1;
