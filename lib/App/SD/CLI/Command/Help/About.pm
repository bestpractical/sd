package App::SD::CLI::Command::Help::About;
use Any::Moose;
extends 'App::SD::CLI::Command::Help';

sub run {
    my $self = shift;
    my ${cmd}= $self->cli->get_script_name;
    $self->print_header('About SD');

print <<EOF
sd is a peer-to-peer replicated ticket tracking system built on the
Prophet database and synchronization framework. sd is designed for
inter-organization replication and sharing, as well as offline
operation. For more information, join us at http://syncwith.us/.

sd was originally conceived and designed by Jesse Vincent and Chia-liang
Kao at Best Practical Solutions. Many others have contributed to sd.
For a full author list, type:

    ${cmd}help authors

sd is open-source software, distributed under the terms of the MIT
license. You are free to use this software, modify it and redistribute
your changed version. You are not required to share your changes
to this software, however, the authors would appreciate it if you
would contribute improvements so that they may be shared with the
community. For license details, type:

    ${cmd}help copying
EOF

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

