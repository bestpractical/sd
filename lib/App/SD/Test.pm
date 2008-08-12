package App::SD::Test;

use warnings;
use strict;

require Prophet::Test;
use base qw/Exporter/;
our @EXPORT = qw(create_ticket_ok create_ticket_comment_ok get_uuid_for_luid get_luid_for_uuid);

$ENV{'PROPHET_APP_CONFIG'} = "t/prophet_testing.conf";

sub create_ticket_ok {
    my @args = (@_);
    my ( $uuid, $luid );
    Prophet::Test::run_output_matches( 'sd', [ 'ticket', 'create', '--', @args ],
        [qr/Created ticket (.*?)(?{ $luid = $1})\s+\((.*)(?{ $uuid = $2 })\)/]
    );

    return ( $luid, $uuid );
}

sub create_ticket_comment_ok {
    my @args = (@_);
    my ( $uuid, $luid );
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    Prophet::Test::run_output_matches(
        'sd',
        [ 'ticket', 'comment', 'create', @args ],
        [qr/Created comment (.*?)(?{ $luid = $1})\s+\((.*)(?{ $uuid = $2 })\)/]
    );

    return ( $luid, $uuid );
}


sub get_uuid_for_luid {
        my $luid = shift;
    my ($ok, $out, $err) =  Prophet::Test::run_script( 'sd', [ 'ticket', 'show', '--batch', '--id', $luid ]);
    if ($out =~ /^id: \d+ \((.*)\)/) {
            return $1;
    }
    return undef;
}


sub get_luid_for_uuid {
        my $uuid = shift;
    my ($ok, $out, $err) =  Prophet::Test::run_script( 'sd', [ 'ticket', 'show', '--batch', '--id', $uuid ]);
    if ($out =~ /^id: (\d+)/) {
            return $1;
    }
    return undef;
}

