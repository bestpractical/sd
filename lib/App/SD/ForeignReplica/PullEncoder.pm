package App::SD::ForeignReplica::PullEncoder;
use Moose;

sub warp_list_to_old_value {
    my $self         = shift;
    my $current_value = shift ||'';
    my $add          = shift;
    my $del          = shift;

    my @new = grep { defined } split( /\s*,\s*/, $current_value );
    my @old = (grep { defined $_ && $_ ne $add } @new, $del ) || ();
    return join( ", ", @old );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
