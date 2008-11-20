package App::SD::ForeignReplica::PullEncoder;
use Moose;

sub warp_list_to_old_value {
    my $self    = shift;
    my $current = shift;
    my $add     = shift;
    my $del     = shift;
    $_ = '' foreach grep !defined, $current, $add, $del;

    my @new = grep defined && length, split /\s*,\s*/, $current;
    my @old = grep defined && length && $_ ne $add, (@new, $del);
    return join( ", ", @old );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
