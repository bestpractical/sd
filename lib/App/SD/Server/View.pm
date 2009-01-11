use warnings;
use strict;

package App::SD::Server::View;
use base 'Prophet::Server::View';

use Template::Declare::Tags;
use Prophet::Server::ViewHelpers;

use App::SD::Model::Ticket;
use App::SD::Model::Comment;
use App::SD::Collection::Ticket;


template '/css/sd.css' => sub {
        outs_raw( '

body {
  font-family: sans-serif;
  background: #601;
  margin: 0;
  padding: 0;
}
  

div.page {
    align: center;
    max-width: 800px;
    background: #fff;
    margin: 0;
    padding: 0;
    margin-left: auto;
    margin-right: auto;
    margin-top: 1em;
    margin-bottom: 1em;
    padding-left: 1em;
    padding-right: 1em;
    padding-bottom: 2em;
    -moz-border-radius: 1em;
    -webkit-border-radius: 1em;
}

div.project-name {
    padding-top: 1em;
    font-style: italic;
    font-family: serif;
}

h1 {
   padding:  0.5em;
   font-size: 1.4em;
   background: #ffc;
}

div.ticket_list ul li span {
   float: left;
   padding: 0.2em;
}

table.tablesorter thead th {
    color: #1133AA;
}

table.tablesorter thead tr .headerSortDown, 
table.tablesorter thead tr .headerSortUp, 
table.tablesorter thead tr th:hover {
    background-color: #ccc;
}

th.headerSortUp,
th.headerSortDown {
    background: #ccc;
}

ul.page-nav {
    float: right;
    margin-top: 0.5em;
    font-size: 0.7em;
}


ul.page-nav li ul li {
    background: #c00;
}

ul.comments {
    list-style: none;
}

ul.comments span.metadata {
    color: #666; 

}

textarea:focus, input:focus { 
   padding: 2px;
   padding-left: 1px;
   background-color: #ffc;
}

input[type=submit] {
    background: #1133AA;
    color: #fff;
    margin: 0.5em;
    padding: 0.5em;
    position: relative;
    top: 1em;
    left: 38.5em;
}
input[type=submit]:hover {
    background: #002299; 
}


textarea.prop-content {
    height: 10em;
    width: 40em;

}

label.prop-content {
    display: none;
}

div.widget label {
    display: inline-block;
    width: 8em;
    font-size: 0.8em;
    text-align: right;
    padding-right: 0.5em;
    color: #666;
    font-weight: bold;
}

div.widget div.value {
    display: inline-block;
}

div.widget {
    padding: 0.5em;
    margin-left: 1em;
    margin-right: 1em;
    border-bottom: 1px solid #ccc;
    border-top: 1px solid #ccc;
}

ul.page-nav li {
    background: #ddd;
    border: 0;
}

ul.page-nav li:hover,
ul.page-nav li.sfHover,
ul.page-nav a:focus,
ul.page-nav a:hover, ul.page-nav a:active { 
    background: #ccc;
}

ul.page-nav {
    padding: 0;
    background: #601;
}

ul.page-nav a {
    border-top: 1px solid #eee;
}

.prop-summary {
    width: 80%;

}

.widget:nth-child(odd) {
    background: #f5f5f5;
}


.widget>.widget {
    border-top: none;
}

dl.history dt {
    margin-top: 0.5em; 
    border-top: 1px solid #ccc;
    padding: 0.5em;
    color: #666; 
}

dl.history dt .created {
    padding-right: 1em;

}

dl.history dt .creator {
    width: 10em;
    display: inline-block;
}

dl.history dt .original_sequence_no {
    color: #ccc;
}

dl.history dt .original_sequence_no:after {
    content: " @ ";
}

dl.history dt .original_source_uuid {
    color: #ccc;
}

dl.history dd ul { 
    list-style: none;
}

ul.comments li {
    border-top: 1px solid #ccc;
    padding: 0.5em;
    margin-left: 1em;
    margin-right: 1em;
    border-bottom: 1px solid #ccc;
}

ul.comments li .content {
    margin-top: 1em;
    white-space: pre;
    font-family: monospace;
    font-size: 0.9em;
    overflow-x: auto;
}

ul.comments li:nth-child(odd) {
    background: #f5f5f5;
}


' );
};

template '/' => page {'Open tickets'}
content {
    show('/tickets/open');

};

template 'milestones' => page {'Project milestones'} content {
    show 'milestone_list';
};


template 'milestone_list' => sub {
    my $self = shift;
    my $milestones = $self->app_handle->setting( label => 'milestones' )->get();

    div { { class is 'pagesection'};
        ul{
    foreach my $milestone (@$milestones) {
            li {
                a {{ href is '/milestone/'.$milestone} $milestone }

            }    

    }
        }
    }

};

template 'no_component' => sub {show 'component' => undef};

template 'component' => page { 'Component: ' . ( $_[1] || '<i>none</i>' ) }
content {
    my $self      = shift;
    my $component = shift;

    h2 {'Open tickets for this component'};

    $self->show_tickets(
        sub {my $item = shift;
            ( ( $item->prop('component') || '' ) eq $component && $item->has_active_status )
                ? 1
                : 0;
        }
    );
};

template 'no_milestone' => sub { show 'milestone' => undef };
template 'milestone' => page { 'Milestone: ' . ( $_[1] || '<i>none</i>' ) }
content {
    my $self      = shift;
    my $milestone = shift;

    h2 {'Open tickets for this milestone'};

    $self->show_tickets(
        sub {my $item = shift;
            ( ( $item->prop('milestone') || '' ) eq ($milestone || '') && $item->has_active_status )
                ? 1
                : 0;
        }
    );

};

sub show_tickets {
    my $self     = shift;
    my $callback = shift;

    my $tickets = App::SD::Collection::Ticket->new(
        app_handle => $self->app_handle,
        handle     => $self->app_handle->handle
    );
    $tickets->matching($callback);
    show( '/ticket_list', $tickets );
}

template edit_ticket => page {

    my $self = shift;
        my $id = shift;
        my $ticket = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $ticket->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

       $ticket->luid.": ".$ticket->prop('summary');



} content {
    my $self = shift;
        my $id = shift;
        my $ticket = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $ticket->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

       title is "Update ticket: ". $ticket->luid.": ".$ticket->prop('summary');

    ul { {class is 'actions'};
        li { a {{ href is '/ticket/'.$ticket->uuid.''}; 'Show'}; };
    };

    form {
        my $f = function(
            record => $ticket,
            action => 'update',
            order => 1,
            name => 'edit-ticket'
        );
        for my $prop ('summary') { 
            div { { class is "widget $prop"}; 
                    widget( function => $f, prop => $prop, autocomplete => 0 ) };
                    }
        for my $prop ('status', 'milestone', 'component',  
                       'owner',  'due',     'reporter') {

            div { { class is "widget $prop"}; 
                    widget( function => $f, prop => $prop ) };
        }
        h2 { 'Add a comment' };

        my $c = function(
            record => App::SD::Model::Comment->new(     
                    app_handle => $self->app_handle ),
            action => 'create',
            order => 2,
            name => 'update-ticket-comment'
        );

           hidden_param( function      => $c, 
                          prop          => 'ticket', 
                          value =>  $ticket->uuid);
        for my $prop (qw(content)) {
            div { widget( function => $c, prop => $prop, 
                            type => 'textarea', autocomplete => 0)};
        }

        input { attr { label => 'save', type => 'submit' } };
    };
};



template new_ticket => page {'Create a new ticket'} content {
    my $self = shift;

    form { { class is 'create-ticket'};

        my $f = function(
            record =>
                App::SD::Model::Ticket->new( app_handle => $self->app_handle ),
            action => 'create',
            order => 1,
            name => 'create-ticket'
        );
        for my $prop ('summary') {
            div {
                { class is "widget $prop" };
                widget( function => $f, prop => $prop, autocomplete => 0 );
            };
        }


        for my $prop (
            'status', 'milestone', 'component',  
            'reporter',
            'owner',  'due',     
            ) {

            div { {class is 'widget '.$prop};
                 widget( function => $f, prop => $prop ) };
        }
        h2 { 'Initial comments on this ticket' };

        my $c = function(
            record => App::SD::Model::Comment->new(     
                    app_handle => $self->app_handle ),
            action => 'create',
            order => 2,
            name => 'create-ticket-comment'
        );

            param_from_function(
                function      => $c,
                prop          => 'ticket',
                from_function => $f,
                from_result   => 'record_uuid'
            );
        for my $prop (qw(content)) {

            div { widget( function => $c, prop => $prop, type => 'textarea', autocomplete => 0)};
        }

        input { attr { label => 'save', type => 'submit' } };
    };
};

template footer => sub { 

    div { id is 'project-versions';
outs("SD $App::SD::VERSION - Issue tracking for the distributed age - ".
            " Prophet $Prophet::VERSION");

    }
};

template header => sub {
    my $self = shift;
    my $title = shift;
    outs_raw($self->nav->render_as_menubar);
    div { class is 'project-name';
            "SD for ".$self->app_handle->setting( label => 'project_name' )->get()->[0]};
    h1 { $title };
};


template '/tickets/open' => sub {
    my $self = shift;
    $self->show_tickets (sub { my $item = shift; return $item->has_active_status ? 1 : 0; });

};

private template 'ticket_list' => sub {
    my $self   = shift;
    my $tickets = shift;
    my $id = substr(rand(10),2); # hack  to get a unique id
    table {
        { class is 'tablesorter'; id is $id; };
        thead {     
            row {
            th { 'id'};
            th {'Status'};
            th {'Owner'};
            th {'Summary'};
            th {'Created'};
            }
        };
        tbody {
        for my $ticket (@$tickets) {
            row {

                cell { ticket_link( $ticket => $ticket->luid );};
                for (qw(status owner summary created)) {
                cell{ class is $_;  $ticket->prop($_) };
                }
                }

            }
        };
        };
         script {outs_raw(qq{
            \$(document).ready(function() { \$("#@{[$id]}").tablesorter(); } ); 
        });
        }
        
        };

template 'show_ticket' => page {
        my $self = shift;
        my $id = shift;
        my $ticket = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $ticket->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

       $ticket->luid.": ".$ticket->prop('summary');
    } content {
        my $self = shift;
        my $id = shift;
        my $ticket = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $ticket->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);
    ul { {class is 'actions'};
        li { a {{ href is '/ticket/'.$ticket->uuid.'/edit'}; 'Edit'}; };
    };

        show ticket_basics      => $ticket;
        show ticket_attachments => $ticket;
        show ticket_comments    => $ticket;
        show ticket_history     => $ticket;

    };


sub _by_creation_date { $a->prop('created') cmp $b->prop('created') };


private template 'ticket_basics' => sub {
    my $self = shift;
    my $ticket = shift;
        my $props = $ticket->get_props;
        div { { class is 'ticket-props'};
        for my $key (sort keys %$props) {
            div { class is 'widget'; 
                label{ $key };
            div { { class is 'value '.$key}; $props->{$key};
        
            } 
            }
        }
        };
};
template ticket_attachments => sub {
    my $self = shift;
    my $ticket = shift;


};
template ticket_history => sub {
    my $self = shift;
    my $ticket = shift;

   
    h2 { 'History'};
    
    dl { { class is 'history'};
    for my $changeset  (sort {$a->created cmp $b->created}  $ticket->changesets) {
        dt {
                span { { class is 'created'};  $changeset->created};
                span { { class is 'creator'};  $changeset->creator || i { 'Missing author'};  };
                span { { class is 'original_sequence_no'};  $changeset->original_sequence_no};
                span { { class is 'original_source_uuid'}; $changeset->original_source_uuid };
                };
        dd { 
                for my $change ($changeset->changes) {
                    next unless $change->record_uuid eq $ticket->uuid;
                        ul {
                            map { li {$_->summary} } $change->prop_changes;
                        };
                    }
                
            }
        }
    }

};

template ticket_comments => sub {
    my $self     = shift;
    my $ticket    = shift;
    my @comments = sort  @{ $ticket->comments };
    if (@comments) {
        h2 { { class is 'conmments'};  'Comments'};
        ul { { class is 'comments'}; 
            for my $comment (@comments) {
                li {
                    span { {class is 'metadata'};  $comment->prop('created') . " " . $comment->prop('creator'); }
                    div { class is 'content'; 
                        $comment->prop('content') || i { 'No body was entered for this comment'} };
                }
            }
        }
    }

};


sub ticket_link {
    my $ticket   = shift;
    my $label = shift;
    span {
        class is 'ticket-link';
        a {
            {
                class is 'ticket';
                href is '/ticket/' . $ticket->uuid;
            };
            $label;
        }
    };
}
1;
