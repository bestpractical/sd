package App::SD;
use Moose;

extends 'Prophet::App';
our $VERSION = '0.01';


sub database_settings {
{ 
        statuses            => ['24183C4D-EFD0-4B16-A207-ED7598E875E6' => qw/new open stalled closed/],
        default_status      => ['2F9E6509-4468-438A-A733-246B3061003E' => 'new' ],
        components          => ['6CBD84A1-4568-48E7-B90C-F1A5B7BD8ECD' => qw/core ui docs tests/],
        default_component   => ['0AEC922F-57B1-44BE-9588-816E5841BB18' => 'core'],
        milestones          => ['1AF5CF74-A6D4-417E-A738-CCE64A0A7F71' => qw/alpha beta 1.0/]
};

}

__PACKAGE__->meta->make_immutable;

no Moose;
1;
