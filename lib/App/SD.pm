package App::SD;
use Any::Moose;
use App::SD::Config;

extends 'Prophet::App';

our $VERSION = '0.74';

has '+config' => (
    default => sub {
        my $self = shift;
        $ENV{PROPHET_APP_CONFIG} = $ENV{SD_CONFIG} if defined $ENV{SD_CONFIG};
        return App::SD::Config->new( app_handle => $self, confname => 'sdrc' );
    }
);

use constant DEFAULT_REPLICA_TYPE => 'sqlite';

sub default_replica_type {
        my $self = shift;
            return $ENV{'PROPHET_REPLICA_TYPE'} || DEFAULT_REPLICA_TYPE;
}


sub database_settings {
{ 
        statuses            => ['24183C4D-EFD0-4B16-A207-ED7598E875E6' => qw/new open stalled closed rejected/],
        active_statuses     => ['C879A68F-8CFE-44B5-9EDD-14E53933669E' => qw/new open/],
        default_status      => ['2F9E6509-4468-438A-A733-246B3061003E' => 'new' ],
        components          => ['6CBD84A1-4568-48E7-B90C-F1A5B7BD8ECD' => qw/core ui docs tests/],
        default_component   => ['0AEC922F-57B1-44BE-9588-816E5841BB18' => 'core'],
        milestones          => ['1AF5CF74-A6D4-417E-A738-CCE64A0A7F71' => qw/alpha beta 1.0/],
        default_milestone   => ['BAB613BD-9E25-4612-8DE3-21E4572859EA' => 'alpha'],

        project_name        => ['3B4B297C-906F-4018-9829-F7CC672274C9' => 'Your SD Project'],
        common_ticket_props => ['3f0a074f-af13-406f-bf7b-d69bbf360720' => qw/id summary status milestone component owner created due creator reporter original_replica/],
        prop_descriptions   => ['c1bced3a-ad2c-42c4-a502-4149205060f1',
        {   summary =>
              "a one-line summary of what this ticket is about",
            owner =>
              "the email address of the person who is responsible for this ticket",
            due =>
              "when this ticket must be finished by",
            reporter =>
              "the email address of the person who reported this ticket"
        },
        ],
    };
}

__PACKAGE__->meta->make_immutable;

no Any::Moose;
1;
