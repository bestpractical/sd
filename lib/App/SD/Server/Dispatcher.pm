package App::SD::Server::Dispatcher;
use Prophet::Server::Dispatcher -base;

on qr'.' => sub {
    my $self = shift;
    $self->server->nav->child( home => label => 'Home', url => '/');
    $self->server->nav->child( create => label => 'New issue', url => '/issue/new');
    $self->server->nav->child( milestones => label => 'Milestones', url => '/milestones');
    next_rule;

};

under 'GET' => sub {
    on qr'^milestone/([\w\d-]+)$' => sub {
        my $milestone = $1;
        shift->show_template( 'milestone', $milestone );

    };

    on qr'^issue/([\w\d-]+)' => sub {
        my $self = shift;
        $self->show_template( 'show_issue', $1 );
    };
};

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
