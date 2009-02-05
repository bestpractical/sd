package App::SD::CLI::Command::Ticket::Details;
use Any::Moose;
extends 'App::SD::CLI::Command::Ticket::Show';

sub by_creation_date { $a->prop('created') cmp $b->prop('created') };

override run => sub {
    my $self = shift;

    $self->require_uuid;
    my $record = $self->_load_record;

    print "\n=head1 METADATA\n\n";
    super();

    my @attachments = sort by_creation_date @{$record->attachments};
    if (@attachments) {
        print "\n=head1 ATTACHMENTS\n\n";
        print $_->format_summary . "\n"
            for @attachments;
    }

    my @comments = sort by_creation_date @{$record->comments};
    if (@comments) {
        print "\n=head1 COMMENTS\n\n";
        for my $comment (@comments) {
            my $creator = $comment->prop('creator');
            my $created = $comment->prop('created');
            my $content = $comment->prop('content');
            print "$creator: " if $creator;
            print "$created\n$content\n\n";
        }
    }

    print "\n=head1 HISTORY\n\n";
    print $record->history_as_string;
};

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

