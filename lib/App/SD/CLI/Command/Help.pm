package App::SD::CLI::Command::Help;
use Moose;
extends 'Prophet::CLI::Command';
with 'App::SD::CLI::Command';

sub title {
    my $self = shift;

}

sub _get_cmd_name {
    my $self = shift;
    return '' if $self->cli->interactive_shell;
    my $cmd = $0;
    $cmd =~ s{^(.*)/}{}g;
    return $cmd;
}


sub print_header {
    my $self = shift;
    my $title = shift;
    my $string =  "sd ".$App::SD::VERSION." - " .$title;
    
    print "\n".$string . "\n";
    print '-' x ( length($string));
    print "\n";

}

sub run {
    my $self = shift;
    my $cmd = $self->_get_cmd_name;

    $self->print_header("Help Index");


print <<EOF

$cmd help search      -  Searching for and displaying tickets
$cmd help tickets     -  Working with tickets
$cmd help comments    -  Working with ticket comments
$cmd help attachments -  Working with ticket attachments
$cmd help sync        -  Publishing and importing ticket databases
$cmd help environment -  Environment variables which affect sd

EOF

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

