package App::SD::Server::Dispatcher;
use Prophet::Server::Dispatcher -base;

on qr'^GET/bug/([\w\d-]+)' => sub {
    my $self = shift; 
    warn "my bug is $1";
    $self->show_template('show_bug', $1); 
    
    };
on qr'^GET/(.*)$' => sub {show_template($1)->(@_)};

redispatch_to 'Prophet::Server::Dispatcher';


sub show_template {
    if(ref($_[0])) { 
        # called in oo context. do it now
        my $self = shift;
        my $template = shift;
        $self->server->show_template($template, @_);
    } else {

    my $template = shift;
    return sub {
        my $self = shift;
        $self->server->show_template($template, @_);
    };
    }
}

1;
