package App::SD::Replica::lighthouse;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use Memoize;

use URI;
use Memoize;
use Net::Lighthouse::Project;
use Net::Lighthouse::User;

use Prophet::ChangeSet;

use constant scheme => 'lighthouse';
use constant pull_encoder => 'App::SD::Replica::lighthouse::PullEncoder';
use constant push_encoder => 'App::SD::Replica::lighthouse::PushEncoder';

has lighthouse => ( isa => 'Net::Lighthouse::Project', is => 'rw' );
has remote_url => ( isa => 'Str',                      is => 'rw' );
has account    => ( isa => 'Str',                      is => 'rw' );
has project    => ( isa => 'Str',                      is => 'rw' );
has query      => ( isa => 'Str',                      is => 'rw' );

our %PROP_MAP = ( state => 'status', title => 'summary' );

sub BUILD {
    my $self = shift;

    my ( $auth, $account, $project, $query ) =
      $self->{url} =~ m{^lighthouse:(?:(.*)@)?(.*?)/(.*?)(?:/(.*))?$}
      or die
        "Can't parse lighthouse server spec. Expected
        lighthouse:email:password\@account/project/query or\n"
        ."lighthouse:token\@account/project/query.";
    my $server = "http://$account.lighthouseapp.com";
    $self->query( $query || 'all' );

    my ( $email, $password, $token );
    if ($auth) {
        if ( $auth =~ /@/ ) {
            ( $email, $password ) = split /:/, $auth;
        }
        else {
            $token = $auth;
        }
    }

    unless ( $token || $password ) {
        if ($email) {
            ( undef, $password ) = $self->prompt_for_login(
                uri            => $server,
                username       => $email,
            );
        }
        else {
            ( undef, $token ) = $self->prompt_for_login(
                uri           => $server,
                username      => 'not important',
                secret_prompt => sub {
                    "token for $server: ";
                }
            );
        }
    }

    $self->remote_url($server);
    $self->account( $account );
    $self->project( $project );

    my $lighthouse = Net::Lighthouse::Project->new(
        auth => {
            $email ? ( email => $email, password => $password ) : (),
            $token ? ( token => $token ) : (),
        },
        account => $account,
    );
    $lighthouse->load( $project );
    $self->lighthouse( $lighthouse );
}


sub get_txn_list_by_date {
    my $self   = shift;
    my $ticket = shift;
    my $ticket_obj = $self->lighthouse->ticket;
    $ticket_obj->load($ticket);
        
    my $sequence = 0;
    my @txns = map {
        {
            id      => $sequence++,
            creator => $_->creator_name,
            created => $_->created_at->epoch,
        }
    } $ticket_obj->versions;

    if ( $ticket_obj->attachments ) {
        my $user = Net::Lighthouse::User->new(
            map { $_ => $self->sync_source->lighthouse->$_ }
              grep { $self->sync_source->lighthouse->$_ }
              qw/account email password token/
        );
        for my $att ( $ticket_obj->attachments ) {
            $user->load( $att->uploader_id );
            push @txns,
              {
                id      => $att->id,
                creator => $user->name,
                created => $att->created_at->epoch,
              };
        }
        @txns = sort { $a->created <=> $b->created } @txns;
    }
    return @txns;
}

sub foreign_username {
    my $self = shift;
    my $user =
      Net::Lighthouse::User->new( map { $_ => $self->lighthouse->$_ }
          grep { $self->lighthouse->$_ } qw/account email password token/ );

    if ( $user->token ) {
        # so we use token, let's try to find user's name
        require Net::Lighthouse::Token;
        my $token = Net::Lighthouse::Token->new(
            map { $_ => $self->lighthouse->$_ }
              grep { $self->lighthouse->$_ } qw/account token/
        );
        $token->load( $self->lighthouse->token );
        my $user = Net::Lighthouse::User->new(
            map { $_ => $self->lighthouse->$_ }
              grep { $self->lighthouse->$_ } qw/account token/
        );
        $user->load( $token->user_id );
        return $user->name;
    }
    else {
        # TODO we can't get user's name via email :/
        # wish they augment the api so we can load via email
        return $1 if $user->email =~ /(.*?)@/;
    }
}

sub uuid {
    my $self = shift;
    Carp::cluck "- can't make a uuid for this" unless ($self->remote_url && $self->account && $self->project );
    return $self->uuid_for_url( join( '/', $self->remote_url, $self->project ) );
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
    return {
        project_name    => $self->account . '/' . $self->project,
        active_statuses => $self->lighthouse->open_states_list,
        statuses        => [
            @{ $self->lighthouse->open_states_list },
            @{ $self->lighthouse->closed_states_list }
        ],
        milestones => [ '', map { $_->title } $self->lighthouse->milestones ],
        default_milestone => '',
    };

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
