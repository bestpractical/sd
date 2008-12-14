package App::SD::Server::Dispatcher;
use Prophet::Server::Dispatcher -base;

on qr '.' => sub {
    my $self = shift;
    if (my $result = $self->server->result->get('create-ticket')) {
            if ($result->success) {
                $self->server->_send_redirect( to => '/issue/'.$result->record_uuid);
               }
    }
    next_rule;

};

on qr'.' => sub {
    my $self = shift;
    my $issues = $self->server->nav->child( issues => label => 'Issues', url => '/issues');
    $issues->child( go => label => '<form method="GET" action="/issue"><a href="#">Show issue # <input type=text name=id size=3></a></form>', escape_label => 0);
    my $milestones = $self->server->nav->child( milestones => label => 'Milestones', url => '/milestones');
    

    my $items = $self->server->app_handle->setting( label => 'milestones' )->get();
    
    foreach my $item (@$items) {
        $milestones->child( $item => label => $item, url => '/milestone/'.$item);
    }
    $self->server->nav->child( create => label => 'New issue', url => '/issue/new');
    $self->server->nav->child( home => label => 'Home', url => '/');


    next_rule;

};

under 'GET' => sub {
    on qr'^milestone/([\w\d-]+)$' => sub {
        my $milestone = $1;
        shift->show_template( 'milestone', $milestone );

    };
    on qr'^issue/?$' => sub {
        my $self = shift;
        my $id = $self->server->cgi->param('id');
        if ($id) {
            $self->server->_send_redirect( to => "/issue/$id" );

        } else {
            next_rule;
        }
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
