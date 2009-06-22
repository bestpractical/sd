package App::SD::Replica::trac;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use File::Temp 'tempdir';
use Memoize;

use constant scheme => 'trac';
use constant pull_encoder => 'App::SD::Replica::trac::PullEncoder';
use constant push_encoder => 'App::SD::Replica::trac::PushEncoder';


use Prophet::ChangeSet;

has trac => ( isa => 'Net::Trac::Connection', is => 'rw');
has remote_url => ( isa => 'Str', is => 'rw');
has query => ( isa => 'Maybe[Str]', is => 'rw');
sub foreign_username { return shift->trac->user(@_) }

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
            password => $password,
        )
    );
    $self->trac->ensure_logged_in;
}



sub get_txn_list_by_date {
    my $self   = shift;
    my $ticket = shift;

    my $ticket_obj = Net::Trac::Ticket->new( connection => $self->trac);
    $ticket_obj->load($ticket);
        
    my @txns   = map { { id => $_->date->epoch, creator => $_->author, created => $_->date->epoch } } sort {$b->date <=> $a->date }  @{$ticket_obj->history->entries};
    return @txns;
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

sub database_settings {
    my $self = shift;

    my @resolutions;
    use Net::Trac::TicketSearch;
    my $search = Net::Trac::TicketSearch->new( connection => $self->trac );
    # find an active ticket to get resolution list
    $search->limit(1);
    $search->query( status => [ qw/accepted assigned reopened new/ ] );
    my $result = $search->results->[0];
    if ( $result ) {
        $result->_fetch_update_ticket_metadata;
        @resolutions = @{$result->valid_resolutions};
    }
    else {
        @resolutions = qw/fixed invalid wontfix duplicate
          worksforme/;
    }

    my @active_statuses = qw/new accepted assigned reopened/;
    return {
        active_statuses => [@active_statuses],
        statuses => [ @active_statuses, 'closed', @resolutions ],
    };
}


__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
