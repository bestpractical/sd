package App::SD::CLI::Command::Ticket::Show;
use Any::Moose;
extends 'Prophet::CLI::Command::Show';
with 'App::SD::CLI::Command';
with 'App::SD::CLI::Model::Ticket';

sub ARG_TRANSLATIONS {
    shift->SUPER::ARG_TRANSLATIONS(),
        a => 'all-props',
        s => 'skip-history',
        h => 'with-history',
        b => 'batch';
}

sub by_creation_date { 
    ($a->can('created') ? $a->created : $a->prop('created') )
    cmp 
    ($b->can('created') ? $b->created : $b->prop('created') )
}

sub usage_msg {
    my $self = shift;
    my $cmd = shift || 'show';
    my $script = $self->cli->get_script_name;
    my $type = $self->type ? $self->type . q{ } : q{};

    return <<"END_USAGE";
usage: ${script}${type}${cmd} <record-id> [options]

Options are:
    -a|--all-props      Show props even if they aren't common
    -s|--skip-history   Don't show ticket history
    -h|--with-history   Show ticket history even if disabled in config
    -b|--batch
END_USAGE
}

override run => sub {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    $self->require_uuid;
    my $record = $self->_load_record;

    # prophet uses --verbose to decide whether to show all declared props
    # or not (rather than just the ones returned by props_to_show),
    # but --all-props is more consistent with sd's behaviour in update/create
    if ( $self->has_arg('all-props') ) {
        $self->set_arg( 'verbose' => 1 );
    }

    print "\n= METADATA\n\n";
    super();

    my @history = sort by_creation_date ( @{ $record->comments }, $record->changesets );

    my @attachments = sort by_creation_date @{ $record->attachments };
    if (@attachments) {
        warn ref($_);
        print "\n= ATTACHMENTS\n\n";
        $self->show_attachment($_) for @attachments;
    }

    # allow user to not display history by specifying the --skip-history
    # arg or setting ticket.no-implicit-history-display config item to a
    # true value (can be overridden with --with-history)
    if (!$self->has_arg('skip-history')
        && (  !$self->app_handle->config->get(
                key => 'ticket.no-implicit-history-display',
                as => 'bool',
            ) || $self->has_arg('with-history') )
        )
    {
        print "\n= HISTORY\n\n";
        foreach my $item (@history) {
            if ( $item->isa('Prophet::ChangeSet') ) {
                $self->show_history_entry( $record, $item );
            } elsif ( $item->isa('App::SD::Model::Comment') ) {
                $self->show_comment($item);
            }
        }
    }
    };


sub show_history_entry {
    my $self      = shift;
    my $ticket    = shift;
    my $changeset = shift;
    my $body = '';
    
    for my $change ( $changeset->changes ) {
        next if $change->record_uuid ne $ticket->uuid;
        $body .= $change->as_string() ||next;
        $body .= "\n";
    }

    return '' if !$body;

    $self->history_entry_header(
         $changeset->creator,
        $changeset->created,
        $changeset->original_sequence_no,
        $self->app_handle->display_name_for_replica($changeset->original_source_uuid),
    
    );

    print $body;
}

sub show_attachment {
    my $self       = shift;
    my $attachment = shift;
    print $attachment->format_summary . "\n";
}

sub show_comment {
    my $self    = shift;
    my $comment = shift;

    my $creator      = $comment->prop('creator');
    my $created      = $comment->prop('created');
    my $content_type = $comment->prop('content_type') || 'text/plain';


    my ($creation) = $comment->changesets(limit => 1);

    my $content = $comment->prop('content') || '';
    if ( $content_type =~ m{text/html}i ) {

        $content =~ s|<p.*?>|\n|gismx;
        $content =~ s|</?pre.*?>|\n|gismx;
        $content =~ s|</?b\s*>|*|gismx;
        $content =~ s|</?i\s*>|_|gismx;
        $content =~ s|<a(?:.*?)href="(.*?)".*?>(.*?)</a.*?>|$2 [link: $1 ]|gismx;
        $content =~ s|<.*?>||gismx;
        $content =~ s|\n\n|\n|gismx;
    }

    $self->history_entry_header($creator,
        $created,$creation->original_sequence_no, $self->app_handle->display_name_for_replica($creation->original_source_uuid));
    print $content;
    print "\n\n";
}


sub history_entry_header {
    my $self = shift;
    my ($creator, $created, $sequence, $source) = (@_);
     printf "%s at %s\t\(%d@%s)\n\n",
        ( $creator || '(unknown)' ),
        $created,
        $sequence,
        $source;
    }

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
