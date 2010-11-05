#!/usr/bin/env perl
use strict;
use warnings;

# to run:
# RT_DBA_USER=root RT_DBA_PASSWORD= prove -lv -I/opt/rt3/lib t/big-hm-rt.t

use Prophet::Test;
use App::SD::Test;

# dramatis personae {{{
our (%USERS, @USERS, $CURRENT_USER_DATA);
BEGIN {
    @USERS = qw(alex clkao jesse kevin shawn);
    %USERS = map { $_ => {} } @USERS;

    # generate "as_person" methods which will perform acts on behalf of that
    # person, such as pull from HM or push to RT
    for my $user (@USERS) {
        my $data = $USERS{$user};
        my $function = "as_$user";

        no strict 'refs';
        *$function = sub (&) {
            my $code = shift;

            local $CURRENT_USER_DATA = $data;
            Jifty->web->current_user($data->{hm_current_user});

            $code->();
        };
    }
}
# }}}
# do we have HM and RT? {{{
BEGIN {
    unless (eval 'use RT::Test (); 1') {
        diag $@;
        plan skip_all => 'requires RT 3.8 to run tests.';
    }
}

BEGIN {
    require File::Temp;

    my $skip_all = sub {
        my $reason = shift;
        plan skip_all => "You must define a JIFTY_APP_ROOT environment variable which points to your Hiveminder source tree. I was unable to $reason."
    };

    $skip_all->("find JIFTY_APP_ROOT") unless $ENV{'JIFTY_APP_ROOT'};
    $skip_all->("load Jifty") unless eval "use Jifty; 1";

    push @INC, File::Spec->catdir(Jifty::Util->app_root, "lib");

    $skip_all->("load BTDT::Test") unless eval "use BTDT::Test; 1";
}
# }}}

plan tests => 17;

# setup the servers {{{
RT::Test->import;
no warnings 'once';
RT::Handle->InsertData( $RT::EtcPath . '/initialdata' );

my ($RT_URL) = RT::Test->started_ok;
diag("RT server started at $RT_URL");

my $HM_SERVER = BTDT::Test->make_server;
my $HM_URL = $HM_SERVER->started_ok;
# }}}
# create users {{{
for my $username (@USERS) {
    my $email = "$username\@example.com";
    diag "Creating $username\'s accounts";
# hiveminder {{{
    do {
        my $user_obj = BTDT::Model::User->new(
            current_user => BTDT::CurrentUser->superuser,
        );
        my ($ok, $msg) = $user_obj->create(
            name                  => $username,
            email                 => $email,
            password              => 'password',
            email_confirmed       => 1,
            access_level          => 'guest',
            accepted_eula_version => Jifty->config->app('EULAVersion'),
        );
        $msg ||= 'ok';
        ok($ok, "Created $username HM user: $msg");

        my $current_user = BTDT::CurrentUser->new(email => $email);

        $USERS{$username} = {
            %{ $USERS{$username} },
            hm_user         => $user_obj,
            hm_current_user => $current_user,
        };
    };
# }}}
# RT {{{
    do {
        my $user_obj = RT::User->new($RT::SystemUser);
        my ($ok, $msg) = $user_obj->Create(
            Name         => $username,
            EmailAddress => $email,
        );
        $msg ||= 'ok';
        ok($ok, "Created $username HM user: $msg");

        ($ok, $msg) = $user_obj->PrincipalObj->GrantRight(
            Right => 'SuperUser',
        );
        ok($ok, "Granted $username SuperUser right: $msg");

        $USERS{$username} = {
            %{ $USERS{$username} },
            rt_user => $user_obj,
        };
    };
# }}}
}
# }}}

