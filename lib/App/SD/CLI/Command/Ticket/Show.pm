package App::SD::CLI::Command::Ticket::Show;
use Any::Moose;
extends 'Prophet::CLI::Command::Show';
with 'App::SD::CLI::Command';
with 'App::SD::CLI::Model::Ticket';

__PACKAGE__->register_arg_translations( a => 'all-props', s => 'skip-history',
                                        h => 'with-history', b => 'batch' );

sub by_creation_date { $a->prop('created') cmp $b->prop('created') };

override run => sub {
    my $self = shift;

    $self->require_uuid;
    my $record = $self->_load_record;

    # prophet uses --verbose to decide whether to show all declared props
    # or not (rather than just the ones returned by props_to_show),
    # but --all-props is more consistent with sd's behaviour in update/create
    if ($self->has_arg('all-props')) {
        $self->set_arg('verbose' => 1);
    }

    print "\n= METADATA\n\n";
    super();

    my @attachments = sort by_creation_date @{$record->attachments};
    if (@attachments) {
        print "\n= ATTACHMENTS\n\n";
        print $_->format_summary . "\n"
            for @attachments;
    }

    my @comments = sort by_creation_date @{$record->comments};
    if (@comments) {
        print "\n= COMMENTS\n\n";
        for my $comment (@comments) {
            my $creator = $comment->prop('creator');
            my $created = $comment->prop('created');
            my $content_type = $comment->prop('content_type') ||'text/plain';

            my $content = $comment->prop('content') || '';
            if ($content_type =~ m{text/html}i ){

                $content =~ s|<p.*?>|\n|gismx;
                $content =~ s|</?pre.*?>|\n|gismx;
                $content =~ s|</?b\s*>|*|gismx;
                $content =~ s|</?i\s*>|_|gismx;
                $content =~ s|<a(?:.*?)href="(.*?)".*?>(.*?)</a.*?>|$2 [link: $1 ]|gismx;
                $content =~ s|<.*?>||gismx;
                $content =~ s|\n\n|\n|gismx;
            }

            print "$creator: " if $creator;
            print "$created\n";
            print $content;
            print "\n\n";
        }
    }

    # allow user to not display history by specifying the --skip-history
    # arg or setting disable_ticket_show_history_by_default config item to a
    # true value (can be overridden with --with-history)
    if (!$self->has_arg('skip-history') && (!$self->app_handle->config->get(
                'disable_ticket_show_history_by_default') ||
            $self->has_arg('with-history'))) {
        print "\n= HISTORY\n\n";
        print $record->history_as_string;
    }
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
