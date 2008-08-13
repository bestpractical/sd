package App::SD::Test;

use warnings;
use strict;

require Prophet::Test;
use base qw/Exporter/;
our @EXPORT = qw(create_ticket_ok create_ticket_comment_ok get_uuid_for_luid get_luid_for_uuid);

$ENV{'PROPHET_APP_CONFIG'} = "t/prophet_testing.conf";

=head2 create_ticket_ok ARGS

Creates a new ticket, passing ARGS along to the creation command (after the
props separator).

Returns a list of the luid and uuid of the newly created ticket.

=cut

sub create_ticket_ok {
    my @args = (@_);
    my ( $uuid, $luid );
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    Prophet::Test::run_output_matches( 'sd', [ 'ticket', 'create', '--', @args ],
        [qr/Created ticket (.*?)(?{ $luid = $1})\s+\((.*)(?{ $uuid = $2 })\)/]
    );

    return ( $luid, $uuid );
}

=head2 create_ticket_ok ARGS

Creates a new ticket comment, passing ARGS along to the creation command.

Returns a list of the luid and uuid of the newly created comment.

=cut

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

=head2 create_ticket_ok luid

Takes a LUID and returns the corresponding UUID.

Returns undef if none can be found.

=cut

sub get_uuid_for_luid {
        my $luid = shift;
    my ($ok, $out, $err) =  Prophet::Test::run_script( 'sd', [ 'ticket', 'show', '--batch', '--id', $luid ]);
    if ($out =~ /^id: \d+ \((.*)\)/) {
            return $1;
    }
    return undef;
}

=head2 get_luid_for_uuid UUID

Takes a UUID and returns the corresponding LUID.

Returns undef if none can be found.

=cut

sub get_luid_for_uuid {
        my $uuid = shift;
    my ($ok, $out, $err) =  Prophet::Test::run_script( 'sd', [ 'ticket', 'show', '--batch', '--id', $uuid ]);
    if ($out =~ /^id: (\d+)/) {
            return $1;
    }
    return undef;
}

=head2 create_ticket_with_editor_ok

Creates a ticket and comment at the same time using a spawned editor.  It's
expected that C<$ENV{VISUAL}> has been frobbed into something non-interactive,
or this test will just hang forever.

Returns a list of the ticket luid, ticket uuid, comment luid, and comment uuid.

=cut

sub create_ticket_with_editor_ok {
    my ( $ticket_uuid, $ticket_luid, $comment_uuid, $comment_luid );
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    Prophet::Test::run_output_matches( 'sd', [ 'ticket', 'create' ],
        [qr/Created ticket (.*?)(?{ $ticket_luid = $1})\s+\((.*)(?{ $ticket_uuid = $2 })\)/, qr/Created comment (.*?)(?{ $comment_luid = $1})\s+\((.*)(?{ $comment_uuid = $2 })\)/]
    );

    return ( $ticket_luid, $ticket_uuid, $comment_luid, $comment_uuid );
}
