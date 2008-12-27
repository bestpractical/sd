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


    my $milestones = $issues->child( milestones => label => 'Milestones', url => '/milestones');
    my $items = $self->server->app_handle->setting( label => 'milestones' )->get();
    foreach my $item (@$items) {
        $milestones->child( $item => label => $item, url => '/milestone/'.$item);
    }
    
    my $components = $issues->child( components => label => 'Components', url => '/components');
    my $items = $self->server->app_handle->setting( label => 'components' )->get();
    foreach my $item (@$items) {
        $components->child( $item => label => $item, url => '/component/'.$item);
    }


    $self->server->nav->child( create => label => 'New issue', url => '/issue/new');
    $self->server->nav->child( home => label => 'Home', url => '/');


    next_rule;

};


under 'POST' => sub {
on 'records' => sub { next_rule(); };
    on qr'^issue/([\w\d-]+)/edit$' => sub { shift->server->_send_redirect(to => '/issue/'.$1); };
    on qr'^(.*)$' => sub { shift->server->_send_redirect(to => $1); }
};


under 'GET' => sub {
    on qr'^(milestone|component)/([\w\d-]+)$' => sub {
        my $name = $1;
        my $type = $2;
        shift->show_template( $name => $type );
    };

    on qr'^issue/new' => sub {
        shift->show_template( 'new_issue');

    };

    on qr'^issue/?$' => sub {
        my $self = shift;
        if (my $id = $self->server->cgi->param('id') ) {
            $self->server->_send_redirect( to => "/issue/$id" );
        } else {
            next_rule;
        }
    };

    on qr'^issue/([\w\d-]+)/edit$' => sub {
        my $self = shift;
        $self->show_template( 'edit_issue', $1 );

    };
    on qr'^issue/([\w\d-]+)/?$' => sub {
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
