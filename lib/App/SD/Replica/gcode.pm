package App::SD::Replica::gcode;
use Any::Moose;
extends qw/App::SD::ForeignReplica/;

use Params::Validate qw(:all);
use File::Temp 'tempdir';
use Memoize;

use constant scheme => 'gcode';
use constant pull_encoder => 'App::SD::Replica::gcode::PullEncoder';
use constant push_encoder => 'App::SD::Replica::gcode::PushEncoder';
use Prophet::ChangeSet;

our %PROP_MAP = (
    summary    => 'summary',
    status     => 'status',
    owner      => 'owner',
    reporter   => 'reporter',
    cc         => 'cc',
    closed     => 'completed',
    reported   => 'created',
    labels     => 'tags',
    priority   => 'priority',
    mergedinto => 'merged_into',
    blockedon  => 'blocked_on',
);


has query => ( isa => 'Str', is => 'rw');
has gcode => ( isa => 'Net::Google::Code', is => 'rw');
has project => ( isa => 'Str', is => 'rw');

sub remote_url { return "http://code.google.com/p/".shift->project}
sub foreign_username { return shift->gcode->email(@_) }

sub BUILD {
    my $self = shift;

    # Require rather than use to defer load
    require Net::Google::Code;

    my ( $userinfo, $project ) = $self->{url} =~ m/^gcode:(.*@)?(.*?)$/
        or die "Can't parse Google::Code server spec. Expected gcode:user:password\@k9mail";
    $self->project($project);
    my ( $email, $password );
    # ask password only if there is userinfo but not password
    if ( $userinfo ) {
        $userinfo =~ s/\@$//;
        ( $email, $password ) = split /:/, $userinfo;
        ( undef, $password ) = $self->prompt_for_login( "gcode:$project", $email ) unless $password;
    }

    $self->gcode( Net::Google::Code->new( project => $self->project));
    $self->gcode->load();
}

sub get_txn_list_by_date {
    my $self   = shift;
    my $ticket = shift;

    my $ticket_obj = Net::Google::Code::Issue->new( project => $self->project);
    $ticket_obj->load($ticket);
        
    my @txns = map {
        {
            id      => $_->sequence,
            creator => $_->author,
            created => $_->date->epoch,
        }
      }
      sort { $b->date <=> $a->date } @{ $ticket_obj->comments };
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
    my $issue = $self->gcode->issue;
    $issue->load_predefined;
    my $status = $issue->predefined_status;
    return {
        project_name => $self->project,
        $status
        ? (
            active_statuses => [ map { lc } @{ $status->{open} } ],
            statuses =>
              [ map { lc } @{ $status->{open} }, @{ $status->{closed} } ]
          )
        : (
            active_statuses => [qw/new accepted started/],
            statuses        => [
                qw/new accepted started duplicate fixed verified
                  invalid wontfix done/
            ],
        ),
    };
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
