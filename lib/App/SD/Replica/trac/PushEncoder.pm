package App::SD::Replica::trac::PushEncoder;
use Any::Moose; 
use Params::Validate;
use Time::HiRes qw/usleep/;
has sync_source => 
    ( isa => 'App::SD::Replica::trac',
      is => 'rw');

extends 'App::SD::ForeignReplica::PushEncoder';


sub after_integrate_change {
  usleep(1100); # trac only accepts one ticket update per second. Yes. 
}

sub integrate_ticket_update {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Figure out the remote site's ticket ID for this change's record
    my $remote_ticket_id =
      $self->sync_source->remote_id_for_uuid( $change->record_uuid );
    my $ticket = Net::Trac::Ticket->new( connection => $self->sync_source->trac);
    $ticket->load($remote_ticket_id);
    $ticket->update( %{ $self->_recode_props_for_integrate($change) }, no_auto_status => 1);
    return $remote_ticket_id;
}

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );

    # Build up a ticket object out of all the record's attributes
    my $ticket = Net::Trac::Ticket->new(
       connection    => $self->sync_source->trac);
    my $id = $ticket->create( %{ $self->_recode_props_for_integrate($change) });

    return $id
}

sub integrate_comment {
    my $self = shift;
    my ($change, $changeset) = validate_pos( @_, { isa => 'Prophet::Change' }, {isa => 'Prophet::ChangeSet'} );

    # Figure out the remote site's ticket ID for this change's record

    my %props = map { $_->name => $_->new_value } $change->prop_changes;

    my $ticket_id     = $self->sync_source->remote_id_for_uuid( $props{'ticket'} );
    my $ticket = Net::Trac::Ticket->new( connection => $self->sync_source->trac);
    $ticket->load($ticket_id);
    $ticket->comment( $props{content});
    return $ticket_id;
} 

sub integrate_attachment {
    my ($self, $change, $changeset ) = validate_pos( @_, { isa => 'App::SD::Replica::trac::PushEncoder'}, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' });


    my %props = map { $_->name => $_->new_value } $change->prop_changes;

    my $ticket_id     = $self->sync_source->remote_id_for_uuid( $props{'ticket'} );
    my $ticket = Net::Trac::Ticket->new( connection => $self->sync_source->trac);
    $ticket->load($ticket_id);

    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    my $file = File::Spec->catfile( $tempdir, ( $props{'name'} || 'unnamed' ) );
    open my $fh, '>', $file or die $!;
    print $fh $props{content};
    close $fh;
    $ticket->attach( file => $file) || die "Could not attach file for ticket $ticket_id";
    return $ticket_id;
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        next unless ( $key =~ /^(summary|status|owner)/ );
        if ( $key eq 'status' ) {
            my $active_statuses =
                $self->sync_source->database_settings->{active_statuses};
            if ( grep { $props{$key} eq $_ } @$active_statuses, 'closed' ) {
                $attr{$key} = $props{$key};
            }
            else {
                $attr{$key} = 'closed';
                $attr{resolution} = $props{$key};
            }

        }
        else {
            $attr{$key} = $props{$key};
        }
    }
    return \%attr;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
