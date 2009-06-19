package App::SD::Replica::rt::PushEncoder;
use Any::Moose; 

extends 'App::SD::ForeignReplica::PushEncoder';

use Params::Validate;

has sync_source => 
    ( isa => 'App::SD::Replica::rt',
      is => 'rw');

sub integrate_ticket_update {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos(
        @_,
        { isa => 'Prophet::Change' },
        { isa => 'Prophet::ChangeSet' }
    );
    # Figure out the remote site's ticket ID for this change's record
    my $remote_ticket_id = $self->sync_source->remote_id_for_uuid( $change->record_uuid );
    my $ticket = RT::Client::REST::Ticket->new(
        rt => $self->sync_source->rt,
        id => $remote_ticket_id,
        %{ $self->_recode_props_for_integrate($change) }
    )->store();

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
    my $ticket = RT::Client::REST::Ticket->new(
        rt    => $self->sync_source->rt,
        queue => $self->sync_source->rt_queue(),
        %{ $self->_recode_props_for_integrate($change) }
    )->store( text => "Not yet pulling in ticket creation comment" );

    return $ticket->id;
}

sub integrate_comment {
    my $self = shift;
    my ($change, $changeset) = validate_pos( @_, { isa => 'Prophet::Change' }, {isa => 'Prophet::ChangeSet'} );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my $ticket_id     = $self->sync_source->remote_id_for_uuid( $props{'ticket'} );
    # Figure out the remote site's ticket ID for this change's record


    my $ticket = RT::Client::REST::Ticket->new( rt => $self->sync_source->rt, id => $ticket_id);

    my %content = ( message => $props{'content'},   
                );

    if (  ($props{'type'} ||'') eq 'comment' ) {
        $ticket->comment( %content);
    } else {
        $ticket->correspond(%content);
    }
    return $ticket_id;
} 

sub integrate_attachment {
    my ($self, $change, $changeset ) = validate_pos( @_, { isa => 'App::SD::Replica::rt::PushEncoder'}, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' });

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my $ticket_id = $self->sync_source->remote_id_for_uuid( $props{'ticket'});
    my $ticket = RT::Client::REST::Ticket->new( rt => $self->sync_source->rt, id => $ticket_id );

    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    my $file = File::Spec->catfile( $tempdir, ( $props{'name'} || 'unnamed' ) );
    open my $fh, '>', $file or die $!;
    print $fh $props{content};
    close $fh;
    my %content = ( message     => '(See attachments)', attachments => ["$file"]);
    $ticket->correspond(%content);
    return $ticket_id;
}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        next unless ( $key =~ /^(summary|queue|status|owner|custom)/ );
        if ( $key =~ /^custom-(.*)/ ) {
            $attr{cf}->{$1} = $props{$key};
        } elsif ( $key eq 'summary' ) {
            $attr{'subject'} = $props{summary};
        } else {
            $attr{$key} = $props{$key};
        }
        if ( $key eq 'status' ) {
            $attr{$key} =~ s/^closed$/resolved/;
        }
    }
    return \%attr;
}


__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
