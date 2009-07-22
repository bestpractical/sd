package App::SD::CLI::Command::Help;
use Any::Moose;
extends 'Prophet::CLI::Command';
with 'App::SD::CLI::Command';

sub title {
    my $self = shift;

}

sub version {
    my $self = shift;
    "sd ".$App::SD::VERSION;

}

sub print_header {
    my $self = shift;
    my $title = shift;
    my $string =  join(' - ', $self->version, $title);
    
    
    print "\n".$string . "\n";
    print '-' x ( length($string));
    print "\n";

}

sub run {
    my $self = shift;
    my ${cmd}= $self->get_cmd_name;

    $self->print_header("Help Index");


print <<EOF

${cmd}help intro       -  Getting started with SD
${cmd}help search      -  Searching for and displaying tickets
${cmd}help tickets     -  Working with tickets
${cmd}help comments    -  Working with ticket comments
${cmd}help attachments -  Working with ticket attachments
${cmd}help sync        -  Publishing and importing ticket databases
${cmd}help history     -  Viewing repository history
${cmd}help environment -  Environment variables which affect sd
${cmd}help config      -  Local configuration variables
${cmd}help ticket.summary_format  -  Details of this config variable
${cmd}help aliases     -  Command aliases
${cmd}help settings    -  Database configuration variables

Running '${cmd}help' on a specific command should also redirect you
to the proper help file.

EOF

}

#__PACKAGE__->meta->make_immutable;
#no Any::Moose;

1;

