package App::SD::Server::Dispatcher;
use Prophet::Server::Dispatcher -base;

on qr'^GET/(.*)$' => sub {show_template($1)->(@_)};

redispatch_to 'Prophet::Server::Dispatcher';


sub show_template {
    my $template = shift;
    return sub {
        my $self = shift;
        $self->server->show_template($template);
    };

}

1;
