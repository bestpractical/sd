use warnings;
use strict;

package App::SD::Replica::RT::PullEncoder;
use Moose;

use Params::Validate qw(:all);
use UNIVERSAL::require;

use Memoize;

has sync_source => 
    ( isa => 'App::SD::Replica::RT',
      is => 'rw');

sub run {
    my $self = shift;
    my %args = validate(
        @_,
        {   after    => 1,
            callback => 1,
            query    => 1
        }
    );

    my $first_rev = ( $args{'after'} + 1 ) || 1;

    for my $id ( $self->find_matching_tickets( $args{'query'} ) ) {
        my $ticket
            = $self->sync_source->rt->show( type => 'ticket', id => $id );
        my $txns = $self->find_matching_transactions(
            ticket               => $id,
            starting_transaction => $first_rev
        );

        $ticket = $self->_translate_final_ticket_state($ticket);
        my $changesets = $self->transcode(
            ticket       => $ticket,
            transactions => $txns
        );
        $args{callback}->($_) for (@$changesets);
    }
}

sub transcode {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, transactions => 1, attachments => 0 } );
    my $ticket_before = $args{'ticket'};
    my @changesets;
    for my $txn ( sort { $b->{'id'} <=> $a->{'id'} } @{ $args{'transactions'} } ) {
        my $changeset = $self->txn_to_changeset( $txn,$ticket_before);
        next unless $changeset->has_changes;
        unshift @changesets, $changeset;
    }

    return \@changesets;
}


sub _translate_final_ticket_state {
    my $self   = shift;
    my $ticket = shift;

    $ticket->{'id'} =~ s/^ticket\///g;
    map { $ticket->{ $self->sync_source->uuid . '-' . lc($_) } = delete $ticket->{$_} }
        (qw(Queue id));
    map { delete $ticket->{$_} if ( !defined $ticket->{$_} || $ticket->{$_} eq '' ) } keys %$ticket;
    map { $ticket->{$_} = $self->date_to_iso( $ticket->{$_} ) }
        qw(Created Resolved Told LastUpdated Starts Started);
    map { $ticket->{$_} =~ s/ minutes$// if defined $ticket->{$_} }
        qw(TimeWorked TimeLeft TimeEstimated);
    $ticket->{'Status'} =~ s/^(resolved|rejected)$/closed/;
    return $ticket;
}

=head2 find_matching_tickets QUERY

Returns an RT::Client ticket collection for all tickets found matching your QUERY string.

=cut


sub find_matching_tickets {
    my $self = shift;
    my ($query) = validate_pos(@_, 1);
    return $self->sync_source->rt->search( type => 'ticket', query => $query );
}


=head2 find_matching_transactions { ticket => $id, starting_transaction => $num }

Returns a reference to an array of all transactions (as hashes) on ticket $id after transaction $num.

=cut

sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, starting_transaction => 1 } );
    my @txns;

    my $rt_handle = $self->sync_source->rt;

    for my $txn ( sort $rt_handle->get_transaction_ids( parent_id => $args{'ticket'} ) ) {
        next if $txn < $args{'starting_transaction'}; # Skip things we've pushed
        next if $self->sync_source->prophet_has_seen_transaction($txn);
        my $txn_hash = $rt_handle->get_transaction(
            parent_id => $args{'ticket'},
            id        => $txn,
            type      => 'ticket'
        );
        if ( my $attachments = delete $txn_hash->{'Attachments'} ) {
            foreach my $attach ( split( /\n/, $attachments ) ) {
                next unless ( $attach =~ /^(\d+):/ );
                my $id = $1;
                my $a  = $rt_handle->get_attachment( parent_id => $args{'ticket'}, id        => $id);

                push( @{ $txn_hash->{_attachments} }, $a )
                    if ( $a->{Filename} );

            }

        }
        push @txns, $txn_hash;
    }
    return \@txns;
}

sub txn_to_changeset {
    my ($self, $txn, $ticket_before) = (@_);
    
        if ($ENV{'SD_DEBUG'}) {warn YAML::Dump($txn); use YAML;}
        if ( my $sub = $self->can( '_recode_txn_' . $txn->{'Type'} ) ) {
            my $changeset = Prophet::ChangeSet->new(
                {   original_source_uuid => $self->sync_source->uuid,
                    original_sequence_no => $txn->{'id'},
                }
            );

            if ( ( $txn->{'Ticket'} ne $ticket_before->{$self->sync_source->uuid . '-id'} ) && $txn->{'Type'} !~ /^(?:Comment|Correspond)$/ ) {
                warn "Skipping a data change from a merged ticket" . $txn->{'Ticket'} . ' vs ' . $ticket_before->{$self->sync_source->uuid . '-id'};
                next;
            }



            delete $txn->{'OldValue'} if ( $txn->{'OldValue'} eq '');
            delete $txn->{'NewValue'} if ( $txn->{'NewValue'} eq '');

            $sub->( $self, ticket_before => $ticket_before, txn          => $txn, changeset    => $changeset);
            $self->translate_prop_names($changeset);

            if (my $attachments = delete $txn->{'_attachments'}) {
               foreach my $attach (@$attachments) { 
                    $self->_recode_attachment_create( ticket_before => $ticket_before, txn => $txn, changeset =>$changeset, attachment => $attach); 
               }
            }

            return $changeset;
        } else {
            warn "not handling txn type $txn->{Type} for $txn->{id} yet";
            die YAML::Dump($txn);
        }
    }


sub _recode_attachment_create {
    my $self   = shift;
    my %args   = validate( @_, { ticket_before => 1, txn => 1, changeset => 1, attachment => 1 } );
    my $change = Prophet::Change->new(
        {   record_type => 'attachment',
            record_uuid => $self->sync_source->uuid_for_url( $self->sync_source->rt_url . "/attachment/" . $args{'attachment'}->{'id'} ),
            change_type => 'add_file'
        }
    );
    $change->add_prop_change( name => 'content_type', old  => undef, new  => $args{'attachment'}->{'ContentType'});
    $change->add_prop_change( name => 'date', old  => undef, new  => $self->date_to_iso($args{'txn'}->{'Created'}));
    $change->add_prop_change( name => 'creator', old  => undef, new  => $self->resolve_user_id_to( email => $args{'attachment'}->{'Creator'}));
    $change->add_prop_change( name => 'content', old  => undef, new  => $args{'attachment'}->{'Content'});
    $change->add_prop_change( name => 'name', old  => undef, new  => $args{'attachment'}->{'Filename'});
    $change->add_prop_change( name => 'ticket', old  => undef, new  => $self->sync_source->uuid_for_remote_id( $args{'ticket_before'}->{ $self->sync_source->uuid . '-id'} ));
    $args{'changeset'}->add_change( { change => $change } );
}

sub _recode_txn_Keyword {} # RT 2 - unused
sub _recode_txn_CommentEmailRecord { return; }

sub _recode_txn_EmailRecord     { return; }
sub _recode_txn_AddReminder     { return; }
sub _recode_txn_ResolveReminder { return; }
sub _recode_txn_DeleteLink      { }

sub _recode_txn_Status {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket_before => 1, changeset => 1 } );

    $args{txn}->{'Type'} = 'Set';
        for my $type(qw(NewValue OldValue)) {
                $args{'txn'}->{$type} =~ s/^(resolved|rejected)$/closed/;
        }
    return $self->_recode_txn_Set(%args);
}

sub _recode_txn_Told {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket_before => 1, changeset => 1 } );
    $args{txn}->{'Type'} = 'Set';
    return $self->_recode_txn_Set(%args);
}

sub _recode_txn_Set {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket_before => 1, changeset => 1 } );
        
    
    


    my $change = Prophet::Change->new(
        {   record_type   => 'ticket',
            record_uuid   => $self->sync_source->uuid_for_remote_id( $args{'ticket_before'}->{$self->sync_source->uuid . '-id'} ),
            change_type => 'update_file'
        }
    );

    if ( $args{txn}->{Field} eq 'Queue' ) {
        my $current_queue = $args{'ticket_before'}->{$self->sync_source->uuid .'-queue'};
        my $user          = $args{txn}->{Creator};
        if ( $args{txn}->{Description} =~ /Queue changed from (.*) to $current_queue by $user/ ) {
            $args{txn}->{OldValue} = $1;
            $args{txn}->{NewValue} = $current_queue;
        }

    } elsif ( $args{txn}->{Field} eq 'Owner' ) {
        $args{'txn'}->{NewValue} = $self->resolve_user_id_to( name => $args{'txn'}->{'NewValue'} );
        $args{'txn'}->{OldValue} = $self->resolve_user_id_to( name => $args{'txn'}->{'OldValue'} );
    }

    $args{'changeset'}->add_change( { change => $change } );
    if ( $args{'ticket_before'}->{ $args{txn}->{Field} } eq $args{txn}->{'NewValue'} ) {
        $args{'ticket_before'}->{ $args{txn}->{Field} } = $args{txn}->{'OldValue'};
    } else {
        $args{'ticket_before'}->{ $args{txn}->{Field} } = $args{txn}->{'OldValue'};
        warn $args{'ticket_before'}->{ $args{txn}->{Field} } . " != " . $args{txn}->{'NewValue'} . "\n\n" . YAML::Dump( \%args ); use YAML;
    }
    $change->add_prop_change(
        name => $args{txn}->{'Field'},
        old  => $args{txn}->{'OldValue'},
        new  => $args{txn}->{'NewValue'}

    );

}

*_recode_txn_Steal = \&_recode_txn_Set;
*_recode_txn_Take  = \&_recode_txn_Set;
*_recode_txn_Give  = \&_recode_txn_Set;

sub _recode_txn_Create {
    my $self = shift;
    my %args = validate( @_, {  txn => 1, ticket_before => 1, changeset => 1 } );

    my $change = Prophet::Change->new(
        {   record_type   => 'ticket',
            record_uuid   => $self->sync_source->uuid_for_remote_id( $args{'ticket_before'}->{$self->sync_source->uuid . '-id'} ),
            change_type => 'add_file'
        }
    );

    $args{'changeset'}->add_change( { change => $change } );
    for my $name ( keys %{ $args{'ticket_before'} } ) {

        $change->add_prop_change(
            name => $name,
            old  => undef,
            new  => $args{'ticket_before'}->{$name},
        );

    }

    $self->_recode_content_update(%args);    # add the create content txn as a seperate change in this changeset

}

sub _recode_txn_AddLink {
    my $self      = shift;
    my %args      = validate( @_, { txn => 1, ticket_before => 1, changeset => 1 } );
    my $new_state = $args{'ticket_before'}->{ $args{'txn'}->{'Field'} };
    $args{'ticket_before'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(
        $args{'ticket_before'}->{ $args{'txn'}->{'Field'} },
        $args{'txn'}->{'NewValue'},
        $args{'txn'}->{'OldValue'}
    );

    my $change = Prophet::Change->new(
        {   record_type   => 'ticket',
            record_uuid   => $self->sync_source->uuid_for_remote_id( $args{'ticket_before'}->{$self->sync_source->uuid . '-id'} ),
            change_type => 'update_file'
        }
    );
    $args{'changeset'}->add_change( { change => $change } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'ticket_before'}->{ $args{'txn'}->{'Field'} },
        new  => $new_state
    );

}

sub _recode_content_update {
    my $self   = shift;
    my %args   = validate( @_, { txn => 1, ticket_before => 1, changeset => 1 } );
    my $change = Prophet::Change->new(
        {   record_type => 'comment',
            record_uuid => $self->sync_source->uuid_for_url( $self->sync_source->rt_url . "/transaction/" . $args{'txn'}->{'id'} ),
            change_type => 'add_file'
        }
    );

        $change->add_prop_change( name => 'date', old  => undef, new  => $self->date_to_iso($args{'txn'}->{'Created'}));

    $change->add_prop_change( name => 'type', old  => undef, new  => $args{'txn'}->{'Type'});
    $change->add_prop_change( name => 'creator', old  => undef, new  => $self->resolve_user_id_to( email => $args{'txn'}->{'Creator'}));
    $change->add_prop_change( name => 'content', old  => undef, new  => $args{'txn'}->{'Content'});
    $change->add_prop_change( name => 'ticket', old  => undef, new  => $self->sync_source->uuid_for_remote_id( $args{'ticket_before'}->{ $self->sync_source->uuid . '-id'} ));
    $args{'changeset'}->add_change( { change => $change } );
}

*_recode_txn_Comment    = \&_recode_content_update;
*_recode_txn_Correspond = \&_recode_content_update;

sub _recode_txn_AddWatcher {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket_before => 1, changeset => 1 } );

    my $new_state = $args{'ticket_before'}->{ $args{'txn'}->{'Field'} };

    $args{'ticket_before'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(
        $args{'ticket_before'}->{ $args{'txn'}->{'Field'} },

        $self->resolve_user_id_to( email => $args{'txn'}->{'NewValue'} ),
        $self->resolve_user_id_to( email => $args{'txn'}->{'OldValue'} )

    );

    my $change = Prophet::Change->new(
        {   record_type   => 'ticket',
            record_uuid   => $self->sync_source->uuid_for_remote_id( $args{'ticket_before'}->{$self->sync_source->uuid . '-id'} ),
            change_type => 'update_file'
        }
    );
    $args{'changeset'}->add_change( { change => $change } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'ticket_before'}->{ $args{'txn'}->{'Field'} },
        new  => $new_state
    );

}

*_recode_txn_DelWatcher = \&_recode_txn_AddWatcher;

sub _recode_txn_CustomField {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket_before => 1, changeset => 1 } );

    my $new = $args{'txn'}->{'NewValue'};
    my $old = $args{'txn'}->{'OldValue'};
    my $name;
    if ( $args{'txn'}->{'Description'} =~ /^(.*) $new added by/ ) {
        $name = $1;

    } elsif ( $args{'txn'}->{'Description'} =~ /^(.*) $old delete by/ ) {
        $name = $1;
    } else {
        die "Uh. what to do with txn descriotion " . $args{'txn'}->{'Description'};
    }

    $args{'txn'}->{'Field'} = "CF-" . $name;

    my $new_state = $args{'ticket_before'}->{ $args{'txn'}->{'Field'} };
    $args{'ticket_before'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(
        $args{'ticket_before'}->{ $args{'txn'}->{'Field'} },
        $args{'txn'}->{'NewValue'},
        $args{'txn'}->{'OldValue'}
    );

    my $change = Prophet::Change->new(
        {   record_type   => 'ticket',
            record_uuid   => $self->sync_source->uuid_for_remote_id( $args{'ticket_before'}->{$self->sync_source->uuid . '-id'} ),
            change_type => 'update_file'
        }
    );

    $args{'changeset'}->add_change( { change => $change } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'ticket_before'}->{ $args{'txn'}->{'Field'} },
        new  => $new_state
    );
}

sub resolve_user_id_to {
    my $self = shift;
    my $attr = shift;
    my $id   = shift;
    return undef unless ($id);

    my $user = eval { RT::Client::REST::User->new( rt => $self->sync_source->rt, id => $id )->retrieve};
    if (my $err = $@) {
            warn $err;
           return $attr eq 'name' ? 'Unknown user' : 'nobody@localhost';
        }
    return $attr eq 'name' ? $user->name : $user->email_address;

}

memoize 'resolve_user_id_to';

sub warp_list_to_old_value {
    my $self         = shift;
    my $current_value = shift ||'';
    my $add          = shift;
    my $del          = shift;

    my @new = grep { defined } split( /\s*,\s*/, $current_value );
    my @old = (grep { defined $_ && $_ ne $add } @new, $del ) || ();
    return join( ", ", @old );
}

our $MONNUM = {
    Jan => 1,
    Feb => 2,
    Mar => 3,
    Apr => 4,
    May => 5,
    Jun => 6,
    Jul => 7,
    Aug => 8,
    Sep => 9,
    Oct => 10,
    Nov => 11,
    Dec => 12
};

use DateTime::Format::HTTP;

sub date_to_iso {
    my $self = shift;
    my $date = shift;

    return undef if $date eq 'Not set';
    my $t = DateTime::Format::HTTP->parse_datetime($date);
    return $t->ymd . " " . $t->hms;
}

our %PROP_MAP = (
    subject         => 'summary',
    status          => 'status',
    owner           => 'owner',
    initialpriority => '_delete',
    finalpriority   => '_delete',
    told            => '_delete',
    requestors      => 'reported_by',
    admincc         => 'admin_cc',
    refersto        => 'refers_to',
    referredtoby    => 'referred_to_by',
    dependson       => 'depends_on',
    dependedonby    => 'depended_on_by',
    hasmember       => 'members',
    memberof        => 'member_of',
    priority        => 'priority_integer',
    resolved        => 'completed',
    due             => 'due',
    creator         => 'creator',
    timeworked      => 'time_worked',
    timeleft        => 'time_left',
    lastupdated     => '_delete',
    created         => '_delete',            # we should be porting the create date as a metaproperty
    Queue           => 'queue',
);

sub translate_prop_names {
    my $self      = shift;
    my $changeset = shift;

    for my $change ( $changeset->changes ) {
        next unless $change->record_type eq 'ticket';

        my @new_props;
        for my $prop ( $change->prop_changes ) {
            next if ( ( $PROP_MAP{ lc( $prop->name ) } || '' ) eq '_delete' );
            $prop->name( $PROP_MAP{ lc( $prop->name ) } ) if $PROP_MAP{ lc( $prop->name ) };
            # Normalize away undef -> "" and vice-versa
            for (qw/new_value old_value/) {
                $prop->$_("") if !defined ($prop->$_());
                }
            next if ( $prop->old_value eq $prop->new_value);

#
#            if ( $prop->name eq 'id' || $prop->name eq 'queue') {
#                $prop->old_value( $prop->old_value . '@' . $changeset->original_source_uuid ) if ( $prop->old_value);
#                $prop->old_value( $prop->new_value . '@' . $changeset->original_source_uuid ) if ( $prop->new_value);
#            }

            if ( $prop->name =~ /^cf-(.*)$/ ) {
                $prop->name( 'custom-' . $1 );
            }

            push @new_props, $prop;

        }
        $change->prop_changes( \@new_props );

    }
    return $changeset;
}

1;
