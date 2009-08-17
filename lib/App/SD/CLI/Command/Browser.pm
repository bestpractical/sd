package App::SD::CLI::Command::Browser;
use Any::Moose;

extends 'App::SD::CLI::Command::Server';

override run => sub {
    my $self = shift;
    $self->print_usage if $self->has_arg('h');
    $self->server;  # make sure server is initialised to not delay later

    Prophet::CLI->end_pager();
    print "Browser will be opened after server has been started.\n";
    $self->open_browser(url => 'http://localhost:'. $self->server->port);
    $self->SUPER::run();
};

sub open_browser {
    my $self = shift;
    my %args = (@_);
    my $opener = $self->open_url_cmd;

    if (!$opener) {
        warn "I'm unable to figure out what browser I should open for you.\n";
        return;
    }

    if ($args{url}) {
        defined (my $child_pid = fork) or die "Cannot fork: $!\n";
        if ( $child_pid == 0 ) {
            # child runs this block
            sleep 2;
            if ( $^O eq 'MSWin32' ) {
                system($opener, $args{url}) && die "Couldn't run $opener: $!";
            }
            else {
                exec($opener, $args{url}) or die "Couldn't run $opener: $!";
            }
            exit(0);
        }
        return;     # parent just returns to run the server
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

