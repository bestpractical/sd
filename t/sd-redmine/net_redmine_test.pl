unless ($_ = $ENV{NET_REDMINE_TEST}) {
    plan skip_all => "Need NET_REDMINE_TEST env var";
    exit;
}

sub net_redmine_test {
    my ($server, $user, $password) = split / /,  $ENV{NET_REDMINE_TEST};

    unless ($server && $user && $password) {
        plan skip_all => "No server and/or login credentials.";
        exit;
    }
    return ($server, $user, $password);
}

sub new_redmine {
    my ($server, $user, $password) = net_redmine_test();
    return Net::Redmine->new(url => $server,user => $user, password => $password);
}

use Text::Greeking;
sub new_tickets {
    my ($r, $n) = @_;
    $n ||= 1;

    my $g = Text::Greeking->new;
    $g->paragraphs(1,1);
    $g->sentences(1,1);
    $g->words(8,24);

    return map {
        $r->create(
            ticket => {
                subject => $g->generate,
                description => $g->generate
            }
        );        
    } (1..$n);
}

1;
