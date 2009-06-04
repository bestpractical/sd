#!/usr/bin/perl

package Net::Trac::TestHarness;
use warnings;
use strict;

use Test::More;
use File::Temp qw/tempdir/;
use LWP::Simple qw/get/;
use Time::HiRes qw/usleep/;

#my $x = __PACKAGE__->new(); $x->start_test_server(); warn $x->url; sleep 999;
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub start_test_server {
my $self = shift;

$self->port( int(60000 + rand(2000)));
$self->dir(tempdir( CLEANUP => 1));
$self->init;
$self->daemonize;
return $self->_did_server_start;
}

sub _did_server_start {
    my $self = shift;
    for ( 1 .. 200 ) {
        return 1 if eval { get( $self->url ) };
        usleep 5000;
    }
    die "Server didn't start";
}

sub port {
    my $self = shift;
    if (@_) {
        $self->{_port} = shift;
    }
    return $self->{_port};
}

sub dir {
    my $self = shift;
    if (@_) {
        $self->{_dir} = shift;
    }
    return $self->{_dir};
}

sub pid {
    my $self = shift;
    if (@_) {
        $self->{_pid} = shift;
    }
    return $self->{_pid};
}

sub url {
    my $self = shift;
    if (@_) {
        $self->{_url} = shift;
    }
    return $self->{_url};
}

sub init {
    my $self = shift;
    my $dir  = $self->dir;
    my $port = $self->port;
    open( my $sys,
        "trac-admin $dir/trac initenv proj sqlite:db/trac.db svn ''|" );
    my @content = <$sys>;
    my ($url) = grep { defined $_ }
        map { /Then point your browser to (.*)\./ ? $1 : undef } @content;
    close($sys);
    $url =~ s/8000/$port/;
    $self->url($url);

    # add a test_resolution value
    system("trac-admin $dir/trac resolution add test_resolution");

    $self->_grant_hiro();

}

sub _grant_hiro {
    my $self = shift;
    my $dir = $self->dir;
open (my $sysadm, "trac-admin $dir/trac permission add hiro TRAC_ADMIN|");
my @results = <$sysadm>;
close ($sysadm);

open(my $htpasswd, ">$dir/trac/conf/htpasswd") || die $!;
# hiro / yatta
print $htpasswd "hiro:trac:98aef54bbd280226ac74b6bc500ff70e\n";
close $htpasswd;

};


sub kill_trac {
    my $self = shift;
    return unless $self->pid;
    kill 1, $self->pid;

}
           sub daemonize {
               my $self = shift;
               my $dir = $self->dir;
               my $port = $self->port;
                my $orig_dir = `pwd`;                   
                chomp $orig_dir;
               chdir $dir."/trac";  
               open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
                 open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
               defined(my $pid = fork) or die "Can't fork: $!";
               if ( $pid ) {
                   $self->pid($pid);
                    chdir($orig_dir) || die $!; 
                return $pid;
               } else {
                   open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
               exec("tracd -p $port -a trac,$dir/trac/conf/htpasswd,trac $dir/trac") || die "Tracd";
           }
           }


sub DESTROY {
    my $self = shift;
    $self->kill_trac;
}

           1;
