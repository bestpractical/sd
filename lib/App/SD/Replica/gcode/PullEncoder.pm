package App::SD::Replica::gcode::PullEncoder;
use Any::Moose;
extends 'App::SD::ForeignReplica::PullEncoder';

use Params::Validate qw(:all);
use Memoize;
use DateTime;

has sync_source => (
    isa => 'App::SD::Replica::gcode',
    is  => 'rw',
);

my %PROP_MAP = %App::SD::Replica::gcode::PROP_MAP;

sub ticket_id {
    my $self   = shift;
    return shift->id;
}

sub _translate_final_ticket_state {
    my $self   = shift;
    my $ticket = shift;

    my @labels = @{$ticket->labels};
    my %prop;
    my @tags;

    for my $label (@labels) {
        if ( $label =~ /(.*?)-(.*)/ ) {
            $prop{lc $1} = $2;
        }
        else {
            push @tags, $label;
        }
    }

    my $ticket_data = {
        $self->sync_source->uuid . '-id' => $ticket->id,
        owner                            => $ticket->owner,
        created     => $ticket->reported->ymd . ' ' . $ticket->reported->hms,
        reporter    => $ticket->reporter,
        status      => $self->translate_prop_status( $ticket->status ),
        summary     => $ticket->summary,
        description => $ticket->description,
        tags        => (join ', ', @tags),
        cc          => $ticket->cc,
    };

    for my $p ( keys %prop ) {
        $ticket_data->{$p} = $prop{$p};
    }

    # delete undefined and empty fields
    delete $ticket_data->{$_}
      for grep { !defined $ticket_data->{$_} || $ticket_data->{$_} eq '' || $ticket_data->{$_} eq '----' }
      keys %$ticket_data;

    return $ticket_data;
}

=head2 find_matching_tickets QUERY

Returns a array of all tickets found matching your QUERY hash.

=cut

sub find_matching_tickets {
    my $self                   = shift;
    my %args  = (@_);
    my $query = $args{query};
    my %query;
    if ($query) {
        if ( $query =~ /=/ ) {
            %query = map { /(.+)=(.*)/; $1 => $2 }
              split /&/, $query;
        }
        else {
            $query{q} = $query;
        }
    }

    my $last_changeset_seen_dt = $self->_only_pull_tickets_modified_after()
      || DateTime->from_epoch( epoch => 0 );
    $self->sync_source->log("Searching for tickets. This can take a very long time on initial sync or if you haven't synced in a long time.");
    require Net::Google::Code;

    if ( $Net::Google::Code::VERSION lt '0.15' ) {
        die
"query support is only for Net::Google::Code version not less than 0.15"
          if $args{query};
        require Net::Google::Code::Issue::Search;
        my $search =
          Net::Google::Code::Issue::Search->new(
            project => $self->sync_source->project, );

        if ( $search->updated_after($last_changeset_seen_dt) ) {
            return $search->results;
        }
        else {
            return [];
        }
    }
    else {
        my $issue = Net::Google::Code::Issue->new(
            map { $_ => $self->sync_source->gcode->$_ }
              grep { $self->sync_source->gcode->$_ }
              qw/project email password/ );

        if ( keys %query == 0 ) {

            # we can use old updated_after method here if no query strings
            # loading issue by checking feeds update is more effective, if
            # possible
            local $Net::Google::Code::Issue::USE_HYBRID = 0;
            require Net::Google::Code::Issue::Search;
            my $search =
              Net::Google::Code::Issue::Search->new(
                project => $self->sync_source->project, );

            # 0 here is to not fallback to ->search method
            if ( $search->updated_after( $last_changeset_seen_dt, 0 ) ) {
                return $search->results;
            }
        }

        $query{can} ||= 'all';
        $query{max_results} ||= 1_000_000_000;
        delete $query{q} unless defined $query{q};
        my $results = $issue->list( %query,
            updated_min => $query{updated_min}
              && $query{updated_min} gt "$last_changeset_seen_dt"
            ? $query{updated_min}
            : "$last_changeset_seen_dt" );

        $_->load for @$results;
        return $results;
    }
}

sub _only_pull_tickets_modified_after {
    my $self = shift;

    my $last_pull = $self->sync_source->upstream_last_modified_date();
    return unless $last_pull;
    my $before = App::SD::Util::string_to_datetime($last_pull);
    $self->log_debug( "Failed to parse '" . $self->sync_source->upstream_last_modified_date() . "' as a timestamp. That means we have to sync ALL history") unless ($before);
    return $before;
}

sub translate_ticket_state {
    my $self         = shift;
    my $ticket       = shift;
    my $transactions = shift;

    my $final_state   = $self->_translate_final_ticket_state($ticket);
    my %earlier_state = %{$final_state};

    my $pre_txn;
    for my $txn ( sort { $b->{'serial'} <=> $a->{'serial'} } @$transactions ) {
        $txn->{post_state} = {%earlier_state};

        if ( $txn->{serial} == 0 ) {
            $txn->{pre_state} = {};
            last;
        }

        my $updates = $txn->{object}->updates;

        for my $prop (qw(owner status summary)) {
            next unless exists $updates->{$prop};
            my $value = delete $updates->{$prop};
            $value = '' if ($value eq '----');
            if ( my $sub = $self->can( 'translate_prop_' . $prop ) ) {
                $value = $sub->( $self, $value );
            }

            $earlier_state{ $PROP_MAP{$prop} } =
              $self->warp_list_to_old_value( $earlier_state{ $PROP_MAP{$prop} },
                $value, undef );
            $txn->{post_state}{ $PROP_MAP{$prop} } = $value;
        }

        if ( $updates->{cc} ) {
            my $value = delete $updates->{cc};
            my $is_delete;
            my @cc = split /\s+/, $value;
            for my $value (@cc) {
                if ( $value =~ /^-(.*)$/ ) {
                    $is_delete = 1;
                    $value     = $1;
                }

                $earlier_state{ $PROP_MAP{cc} } =
                  $self->warp_list_to_old_value( $earlier_state{cc},
                    $is_delete ? ( undef, $value ) : ( $value, undef ) );
            }
        }

        if ( $updates->{mergedinto} ) {
            my $value = delete $updates->{mergedinto};
            my $is_delete;
            if ( $value =~ /^-(.*)$/ ) {
                $is_delete = 1;
                $value     = $1;
            }

            $earlier_state{ $PROP_MAP{mergedinto} } =
              $self->warp_list_to_old_value( $earlier_state{mergedinto},
                $is_delete ? ( undef, $value ) : ( $value, undef ) );
            $txn->{post_state}{ $PROP_MAP{mergedinto} } = $value
              unless $is_delete;
        }

        if ( $updates->{labels} ) {
            my $values = delete $updates->{labels};
            for my $value (@$values) {
                my $is_delete;
                if ( $value =~ /^-(.*)$/ ) {
                    $is_delete = 1;
                    $value     = $1;
                }

                my $name;
                if ( $value =~ /(.*?)-(.*)/ ) {
                    $name  = lc $1;
                    $value = $2;
                }
                else {
                    $name = 'labels';
                }

                $name = $PROP_MAP{$name} || $name;

                $earlier_state{$name} =
                  $self->warp_list_to_old_value( $earlier_state{$name},
                    $is_delete ? ( undef, $value ) : ( $value, undef ) );
            }
        }

        $txn->{pre_state} = {%earlier_state};
        $pre_txn->{pre_state} = $txn->{post_state} if $pre_txn;
        $pre_txn = $txn;
    }

# XXX try our best to find historical info
# e.g. 
# comemnt 3 has summary: "foo"
# comment 4 and 5 don't have summary changes
# comment 6 has summary: "bar"
# then we can set comment 4 and 5's summary to 'foo'
    my @sorted = sort { $b->{'serial'} <=> $a->{'serial'} } @$transactions;
    for ( my $i = 0 ; $i < @sorted ; $i++ ) {
        for my $prop (qw(owner status summary)) {
            if ( !$sorted[$i]->{post_state}{ $PROP_MAP{$prop} } ) {
                ( $sorted[$i]->{post_state}{ $PROP_MAP{$prop} } ) =
                  grep { $_ }
                  map  { $_->{post_state}{ $PROP_MAP{$prop} } }
                  @sorted[ $i + 1 .. $#sorted ];
                $sorted[$i]->{post_state}{ $PROP_MAP{$prop} } ||= '';
            }
        }
    }

    return \%earlier_state, $final_state;
}

=head2 find_matching_transactions { ticket => $id, starting_transaction => $num  }

Returns a reference to an array of all transactions (as hashes) on ticket $id after transaction $num.

=cut

sub find_matching_transactions {
    my $self     = shift;
    my %args     = validate( @_, { ticket => 1, starting_transaction => 1 } );
    my @raw_txns = @{ $args{ticket}->comments };

    my @txns;
    for my $txn ( sort { $a->sequence <=> $b->sequence } @raw_txns ) {
        my $txn_date = $txn->date->epoch;

        # Skip things we know we've already pulled
        next if $txn_date < ( $args{'starting_transaction'} || 0 );

        # Skip things we've pushed
        next if (
            $self->sync_source->foreign_transaction_originated_locally(
                $txn_date, $args{'ticket'}->id
            )
          );

        # ok. it didn't originate locally. we might want to integrate it
        push @txns,
          {
            timestamp => $txn->date,
            serial    => $txn->sequence,
            object    => $txn,
          };
    }
    $self->sync_source->log_debug('Done looking at pulled txns');

    return \@txns;
}

sub transcode_create_txn {
    my $self        = shift;
    my $txn         = shift;
    my $create_data = shift;
    my $final_data  = shift;
    my $ticket_id   = $final_data->{ $self->sync_source->uuid . '-id' };
    my $ticket_uuid = 
          $self->sync_source->uuid_for_remote_id($ticket_id);
    my $creator =
      $self->resolve_user_id_to( email_address => $create_data->{reporter} );
    my $created = $final_data->{created};

    my $changeset = Prophet::ChangeSet->new(
        {
            original_source_uuid => $ticket_uuid,
            original_sequence_no => 0,
            creator              => $creator,
            created              => $created,
        }
    );

    my $change = Prophet::Change->new(
        {
            record_type => 'ticket',
            record_uuid => $ticket_uuid,
            change_type => 'add_file',
        }
    );

    for my $prop ( keys %{ $txn->{post_state} } ) {
        $change->add_prop_change(
            name => $prop,
            new  => ref( $txn->{post_state}->{$prop} ) eq 'ARRAY'
            ? join( ', ', @{ $txn->{post_state}->{$prop} } )
            : $txn->{post_state}->{$prop},
        );
    }
    $changeset->add_change( { change => $change } );

    for my $att ( @{ $txn->{object}->attachments } ) {
        $self->_recode_attachment_create(
            ticket_uuid => $ticket_uuid,
            txn         => $txn->{object},
            changeset   => $changeset,
            attachment  => $att,
        );
    }
    return $changeset;
}

# we might get return:
# 0 changesets if it was a null txn
# 1 changeset if it was a normal txn
# 2 changesets if we needed to to some magic fixups.

sub transcode_one_txn {
    my $self               = shift;
    my $txn_wrapper        = shift;
    my $older_ticket_state = shift;
    my $newer_ticket_state = shift;

    my $txn = $txn_wrapper->{object};
    if ( $txn_wrapper->{serial} == 0 ) {
        return $self->transcode_create_txn( $txn_wrapper, $older_ticket_state,
            $newer_ticket_state );
    }

    my $ticket_id   = $newer_ticket_state->{ $self->sync_source->uuid . '-id' };
    my $ticket_uuid =
      $self->sync_source->uuid_for_remote_id( $ticket_id );
    my $changeset = Prophet::ChangeSet->new(
        {
            original_source_uuid => $ticket_uuid,
            original_sequence_no => $txn->sequence,
            creator =>
              $self->resolve_user_id_to( email_address => $txn->author ),
            created => $txn->date->ymd . " " . $txn->date->hms
        }
    );

    my $change = Prophet::Change->new(
        {
            record_type => 'ticket',
            record_uuid => $ticket_uuid,
            change_type => 'update_file'
        }
    );

    for my $prop ( keys %{ $txn_wrapper->{post_state} } ) {
        my $new = $txn_wrapper->{post_state}->{$prop};
        my $old = $txn_wrapper->{pre_state}->{$prop};
        $change->add_prop_change(
            name => $prop,
            new  => $new,
            old  => defined $old ? $old : '',
        ) unless $new eq $old;
    }

#    warn "right here, we need to deal with changed data that gcode failed to record";
    my %updates = %{ $txn->updates };

    my $props = $txn->updates;
    foreach my $prop ( keys %{ $props || {} } ) {
        $prop = lc $prop;
        $change->add_prop_change(
            name => $PROP_MAP{$prop} || $prop,
            old  => $txn_wrapper->{pre_state}->{$PROP_MAP{$prop}},
            new  => $txn_wrapper->{post_state}->{$PROP_MAP{$prop}}
        );
    }

    $changeset->add_change( { change => $change } )
      if $change->has_prop_changes;

    $self->_include_change_comment( $changeset, $ticket_uuid, $txn );

    return unless $changeset->has_changes;
    return $changeset;
}

sub _include_change_comment {
    my $self        = shift;
    my $changeset   = shift;
    my $ticket_uuid = shift;
    my $txn         = shift;

    my $comment = $self->new_comment_creation_change();
   
    if ( my $content = $txn->content ) {
        if ( $content !~ /^\s*$/s ) {
            $comment->add_prop_change(
                name => 'created',
                new  => $txn->date->ymd . ' ' . $txn->date->hms,
            );
            $comment->add_prop_change(
                name => 'creator',
                new =>
                  $self->resolve_user_id_to( email_address => $txn->author ),
            );
            $comment->add_prop_change( name => 'content', new => $content );
            $comment->add_prop_change(
                name => 'content_type',
                new  => 'text/plain',
            );
            $comment->add_prop_change( name => 'ticket', new => $ticket_uuid, );

            $changeset->add_change( { change => $comment } );
        }
    }

    for my $att ( @{ $txn->attachments } ) {
        $self->_recode_attachment_create(
            ticket_uuid => $ticket_uuid,
            txn         => $txn,
            changeset   => $changeset,
            attachment  => $att,
        );
    }
}

sub _recode_attachment_create {
    my $self = shift;
    my %args =
      validate( @_,
        { ticket_uuid => 1, txn => 1, changeset => 1, attachment => 1 } );
    my $change = Prophet::Change->new(
        {
            record_type => 'attachment',
            record_uuid => $self->sync_source->uuid_for_url(
                    $self->sync_source->remote_url
                  . "/attachment/"
                  . $args{'attachment'}->id,
            ),
            change_type => 'add_file',
        }
    );

    $change->add_prop_change(
        name => 'content_type',
        old  => undef,
        new  => $args{'attachment'}->content_type,
    );

    $change->add_prop_change(
        name => 'created',
        old  => undef,
        new  => $args{'txn'}->date->ymd . ' ' . $args{'txn'}->date->hms,
    );
    $change->add_prop_change(
        name => 'creator',
        old  => undef,
        new =>
          $self->resolve_user_id_to( email_address => $args{'txn'}->author )
    );

    $change->add_prop_change(
        name => 'content',
        old  => undef,
        new  => $args{'attachment'}->content,
    );
    $change->add_prop_change(
        name => 'name',
        old  => undef,
        new  => $args{'attachment'}->name,
    );
    $change->add_prop_change(
        name => 'ticket',
        old  => undef,
        new  => $args{ticket_uuid},
    );
    $args{'changeset'}->add_change( { change => $change } );
}

sub translate_prop_status {
    my $self   = shift;
    my $status = shift;
    return lc($status);
}

sub resolve_user_id_to {
    my $self = shift;
    my $to   = shift;
    my $id   = shift;
    return $id . '@gmail.com';

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
