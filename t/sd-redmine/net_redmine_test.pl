unless ($_ = $ENV{NET_REDMINE_TEST}) {
    plan skip_all => "Need NET_REDMINE_TEST env var set to '<project url> <username> <password>'";
    exit;
}

###
### XXX: This piece of code is attempt to reset a local redmine rails
### instance. But FAIL to work. It's left here for reference, maybe
### it'll be made working in the future.
###
# unless ($_ = $ENV{NET_REDMINE_RAILS_ROOT}) {
#     plan skip_all => "Need NET_REDMINE_RAILS_ROOT env var";
#     exit;
# }
# {
#     use Cwd qw(getcwd);
#     my $cwd = getcwd;
#     chdir($ENV{NET_REDMINE_RAILS_ROOT});
#     $ENV{RAILS_ENV}="production";
#     # system "rake db:drop";
#     system "rm db/production.db";
#     system "rake db:create";
#     system "rake config/initializers/session_store.rb";
#     system "rake db:migrate";
#     system "echo en | rake redmine:load_default_data";
#     system qq{script/runner -E "Project.create!(:name => 'test', :identifier => 'test', :is_public => false).set_parent!(nil)"};
#     chdir($cwd);
# }

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
