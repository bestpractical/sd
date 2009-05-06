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

sub new_tickets {
    my ($r, $n) = @_;
    $n ||= 1;

    my (undef, $filename, $line) = caller;

    return map {
        $r->create(
            ticket => {
                subject => "$filename $line " . time,
                description => "$filename $line " . time
            }
        );        
    } (1..$n);
}

1;
