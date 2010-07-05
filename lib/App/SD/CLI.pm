#!/usr/bin/env perl
package App::SD::CLI;
use Any::Moose;
extends 'Prophet::CLI';

use App::SD;
use App::SD::CLI::Dispatcher;

has '+app_class' => (
    default => 'App::SD',
);

sub dispatcher_class { "App::SD::CLI::Dispatcher" }

sub format_change {
    my $self = shift;
    my %args = (
        change          => undef,
        header_callback => undef,
        @_
    );
    my $output = $args{header_callback} ? $args{header_callback}->( $args{change} ) : '' ;

    if ( $args{change}->record_type eq 'comment' && $args{change}->change_type eq 'add_file' ) {
        my $change = $args{change}->as_hash;

        $output .= App::SD::CLI::Command::Ticket::Show->format_comment(
            (   ( $change->{prop_changes}->{'content_type'} && $change->{prop_changes}->{'content_type'}->{new_value} )
                ? $change->{prop_changes}->{'content_type'}->{new_value}
                : 'text/plain'
            ),
            $change->{prop_changes}->{'content'}->{new_value}

        );
    } else {
        if ( my @prop_changes = $args{change}->prop_changes ) {
            $output .= $args{change_header}->( $args{change} ) if ( $args{change_header} );
            $output .= App::SD::CLI->format_prop_changes( \@prop_changes );

        }
    }

    return $output . "\n";

}

sub format_prop_changes {
    my $self         = shift;
    my $prop_changes = shift;
    my $output;
    for (@$prop_changes) {
        if ( defined $_->new_value && defined $_->old_value ) {
            $output .= sprintf( "%18.18s", $_->name ) . ": changed from " . $_->old_value . " to " . $_->new_value;
        } elsif ( defined $_->new_value ) {
            $output .= sprintf( "%18.18s", $_->name ) . ": set to " . $_->new_value;

        } elsif ( defined $_->old_value ) {
            $output .= sprintf( "%18.18s", $_->name ) . ": " . $_->old_value . " deleted";
        } else {
            next;
        }

        $output .= "\n";
    }
    return $output;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

