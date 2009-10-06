package App::SD::Server;
use base 'Prophet::Server';



=head2 database_bonjour_name

Returns the name this database should use to announce itself via bonjour

=cut

sub database_bonjour_name {
    my $self = shift;
    my $name = $self->app_handle->setting( label => 'project_name' )->get->[0];
    my $uuid = $self->handle->db_uuid;
    return "$name ($uuid)";

}


sub css {
    return shift->SUPER::css(@_), "/static/sd/css/main.css";
}

sub js {
    return shift->SUPER::js(@_);
}
1;

