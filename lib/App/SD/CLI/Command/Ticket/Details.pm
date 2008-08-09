package App::SD::CLI::Command::Ticket::Details;
use Moose;
extends 'App::SD::CLI::Command::Ticket::Show';

sub by_creation_date { $a->prop('created') cmp $b->prop('created') };

override run => sub {
    my $self = shift;

    $self->require_uuid;
    my $record = $self->_load_record;

    print "\n=head1 METADATA\n\n";
    super();

    print "\n=head1 ATTACHMENTS\n\n";
    my @attachments = sort by_creation_date @{$record->attachments};
    print $_->format_summary . "\n" for @attachments;

    print "\n=head1 COMMENTS\n\n";
    my @comments = sort by_creation_date @{$record->comments};
    print $_->prop('created') . "\n" . $_->prop('content') . "\n\n" for @comments;

    print "\n=head1 HISTORY\n\n";
    print $record->history_as_string;
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

