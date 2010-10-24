package App::SD::Server;
use Any::Moose;
extends 'Prophet::Server';

has with_browser => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

=head2 database_bonjour_name

Returns the name this database should use to announce itself via bonjour

=cut

sub database_bonjour_name {
    my $self = shift;
    my $name = $self->app_handle->setting( label => 'project_name' )->get->[0];
    my $uuid = $self->handle->db_uuid;
    return "$name ($uuid)";

}


sub css {
    return shift->SUPER::css(@_), "/static/sd/css/main.css";
}

sub js {
    return shift->SUPER::js(@_);
}

# open up a browser after the server has been started (basically a
# hook for the browser command)
sub after_setup_listener {
    my $self = shift;

    local $SIG{CHLD}; # allow browser to be run with system()

    if ( $self->with_browser ) {
        $self->open_browser( url => 'http://localhost:' . $self->port );
    }
}

sub open_browser {
    my $self = shift;
    my %args = (@_);
    my $opener = $self->open_url_cmd;

    if (!$opener) {
        warn "I'm unable to figure out what browser I should open for you.\n";
        return;
    }

    system($opener, $args{url}) && die "Couldn't run $opener: $!";
}

sub open_url_cmd {
    my $self = shift;

    if ( $^O eq 'darwin' ) {
        return 'open';
    }
    elsif ( $^O eq 'MSWin32' ) {
        return 'start';
    }

    for my $cmd (qw|x-www-browser htmlview
                    gnome-open gnome-moz-remote
                    firefox iceweasel opera www-browser w3m lynx|) {
        my $cmd_path = `which $cmd`;
        chomp($cmd_path);
        if ( $cmd_path &&  -f $cmd_path && -x _ ) {
            return $cmd_path;
        }
    }
}

no Any::Moose;
1;

