package App::SD::CLI::Command::Server;
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
    if ($args{url}) {
        fork || do { sleep 2; `$opener $args{url}`; exit};
    }
}

sub open_url_cmd {
    my $self = shift;
    if ( $^O eq 'darwin' ) {
        return 'open';
    } elsif ( $^O eq 'MSWin32' ) {
        return 'start';
    }
    for my $cmd (qw|www-browser htmlview gnome-open gnome-moz-remote 
                    firefox iceweasel opera w3m lynx|) {
        my $cmd_path = `which $cmd`;
        chomp($cmd_path);
        next unless $cmd_path;
        if ( -f $cmd_path && -x _ ) {
            return $cmd_path;
        }
    }
}
