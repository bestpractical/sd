package App::SD::CLI::Command::Browser;
use Any::Moose;

extends 'Prophet::CLI::Command::Server';

sub setup_server {
    my $self = shift;
    my $server = $self->SUPER::setup_server();
    $self->open_browser(url => 'http://localhost:'. $server->port);
    return $server;
}

sub open_browser {
    my $self = shift;
    my %args = (@_);
    my $opener = $self->open_url_cmd;

    if (!$opener) {
        warn "I'm unable to figure out what browser I should open for you.\n";
        return;
    }

    if ($args{url}) {
        return if fork != 0;
        sleep 2;
        exec($opener, $args{url}) or die "Couldn't exec $opener: $!";
    }
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

__PACKAGE__->meta->make_immutable;
no Any::Moose;

