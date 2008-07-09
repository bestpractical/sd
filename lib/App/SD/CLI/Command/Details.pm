package App::SD::CLI::Command::Details;
use Moose;
with 'App::SD::CLI::Command';
with 'App::SD::CLI::Model::Ticket';

use App::SD::CLI::Command::Ticket::Show;
use App::SD::CLI::Command::Ticket::Attachment::Search;
use App::SD::CLI::Command::Ticket::Comments;

sub run {
    my $self = shift;
    print "\n=head1 METADATA\n\n";
    $self->App::SD::CLI::Command::Ticket::Show::run();

    print "\n=head1 ATTACHMENTS\n\n";
    use Clone;
    my $foo = Clone::clone($self);
    $foo->type('attachment');
    bless $foo, 'App::SD::CLI::Command::Ticket::Attachment::Search';
    $foo->run;

    print "\n=head1 COMMENTS\n\n";
    my $bar = Clone::clone($self);
    bless $bar, 'App::SD::CLI::Command::Ticket::Comments';
    $bar->type('comment');
    $bar->App::SD::CLI::Command::Ticket::Comments::run();
}

__PACKAGE__->meta->make_immutable;
no Moose;

