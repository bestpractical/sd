use warnings;
use strict;

package App::SD::Server::View;
use base 'Prophet::Server::View';

use Template::Declare::Tags;
use Prophet::Server::ViewHelpers;

use App::SD::Model::Ticket;
use App::SD::Model::Comment;
use App::SD::Collection::Ticket;


my @BASIC_PROPS = qw(status milestone component owner reporter due created);


template '/css/sd.css' => sub {
        outs_raw( '

html {
  font-family: Helvetica;
  background-color: #601;
  padding: 1em;

}
  

div.page {
    position: relative;
    align: center;
    max-width: 800px;
    min-width: 400px;
    background: #fff;
    margin: 0;
    padding: 0;
    margin-left: auto;
    margin-right: auto;
    padding-top: 1em;
    padding-left: 1em;
    padding-right: 1em;
    padding-bottom: 2em;
    -moz-border-radius: 1em;
    -webkit-border-radius: 1em;
}

div.body { 
    padding-top: 2em;
    margin-top: 2em;
    }

.logo {
    position: absolute;
    margin-left: -1em;
    margin-top: -1em;
    width: 70px;
   background-color: none;
   z-index: 50;
}


div.project-name {
    position: absolute;
    top: 0;
    right: 0;
    left: 0;
    padding-left: 70px;
    color: #fff;
    background-color: #000;
    display: inline;
    font-weight: bold;
    padding-top: 0.25em;
    padding-right: 0.5em;
    padding-bottom: 0.5em;
    -moz-border-radius-topright: 1em;
    -moz-border-radius-bottomright: 0em;
    -webkit-border-top-right-radius: 1em;
    -webkit-border-bottom-right-radius: 0em;
    z-index: 30;
}

h1 {
   position: absolute;
   left: 0;
   right: 0;
   top: 1.1em;
   height: 1em;
   display: block;
   overflow: hidden;
   text-overflow:ellipsis;
   padding-top:0.3em;
   padding-left: 70px;
   padding-bottom: 0.3em;
   margin-bottom: 2.5em;
   background-color: #666;
   color: #fff;
   text-decoration: none;
   font-size: 1.6em;
   border-bottom: 1px solid #ccc;
   z-index: 0;
}

h2 {
   padding:  0.5em;
 text-decoration: none;
   font-weight: bold;
   font-size: 1.4em;

}

ul.actions {
    align: center;
    display: block;
    min-width: 1em;
    max-width: 12em;
    margin-left: auto;
    margin-right: auto;
    padding: 0.25em;   
}

ul.actions li {
    list-style: none;
    border-right: 1px solid white;
    padding: 0.25em;
    display: inline;
    background: #ddd;
} 

ul.actions li:first-child {
    -moz-border-radius-topleft: 0.25em;
    -webkit-border-top-left-radius: 0.25em;
}

ul.actions li:last-child {
    -moz-border-radius-topright: 0.25em;
    -webkit-border-top-right-radius: 0.25em;
}


ul.actions li a { 
    text-decoration: none;
    color: #1133AA;
    padding: 0.5em;
    font-size: 0.8em;
}

ul.actions li:hover { 
    background: #ccc;
}

div.ticket_list ul li span {
   float: left;
   padding: 0.2em;
}

table.tablesorter thead th {
    color: #999;
    background-color: #fff;
}
table.tablesorter thead tr .header {
    background: none;
    border-bottom: 1px solid #666;
}
table.tablesorter thead tr .headerSortDown, 
table.tablesorter thead tr .headerSortUp, 
table.tablesorter thead tr th:hover {
    text-decoration: underline;
    background-color: #fff;
    color: #666;
}
table.tablesorter thead tr th {
    background-color: #fff;
}


th.headerSortUp,
th.headerSortDown {
    background: #fff;
}

    
}


ul.comments {
    list-style: none;
}

ul.comments span.metadata {
    color: #666; 

}

textarea:focus, input:focus { 
/*   padding: 2px;
   padding-left: 1px; */
   background-color: #ffc;
}

div.submit {
    width: auto;
    display: block;
    margin-top: 1em;
    margin-left: 2em;
    margin-right: 2em;
    text-align: right;
    padding-right: 1em;
}


input[type=submit] {
    background: #1133AA;
    color: #fff;
    margin: 0.5em;
    padding: 0.5em;
    top: 1em;
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
    background-color: transparent;
    font-weight: bold;
    margin: 0;
    padding: 0;
    border: 0;
    padding-bottom: 0.8em;
}

div.widget div.value {
    display: inline-block;
    padding-top: 0.35em;
    padding-left: 0.6em;
    font-size: 0.95em;
}

div.widget input {
    margin-top: 0em;
    font-size: 0.95em;
    margin-left: 0.2em;
    padding: 0.2em;
}

div.comment-form {
    border: 1px solid #999;
    margin-left: 1em;
    margin-right: 1em;
    margin-top: 2em;
    padding: 2em;
    padding-top: 0;
    align: center;
    background: #eee;
}

div.comment-form textarea {
    width: 100%;

}

div.comment-form h2 {
    margin-top: -1.5em;

}



div.widget {
    padding: 0.5em;
    padding-top: 0.6em;
    marging-bottom: 0.2em;
    margin-left: 1em;
    margin-right: 1em;
    height: 1.6em;
    border-bottom: 1px solid #ccc;
}

.widget {
    border-top: 1px solid #ccc;
}

.widget>.widget {
    border-top: none;
}

div.widget.status, div.widget.component, div.widget.milestone {
    display: inline-block;
    padding-top: 0.5em;
    padding-bottom: 1.75em;
    margin: 0;
    padding-left: 0.5em;
    padding-right: 1em;
    margin-right: -0.3em;
    width: 29%;
}

div.widget.status {
    margin-left: 1em;
}

div.widget.status label, div.widget.component label, div.widget.milestone label
{
display: block;
text-align: left;
padding-left: 0.5em;
padding-bottom:0.25em;
}



div.widget.status input, 
div.widget.component input, 
div.widget.milestone input,
div.widget.status .value, 
div.widget.component .value, 
div.widget.milestone .value {

width: 100%;

}

.other-props { 
    padding-top: 0em;

}

.other-props .widget label,
.other-props .widget .label {
    width: 4em;
}
.other-props .widget {
    width: 40%;
}

ul.page-nav {
    position: absolute;
    top: 0;
    right: 1.25em;
    font-size: 0.7em;
    z-index: 1000;
    color: #ccc;
    padding: 0;
}

ul.page-nav li, ul.page-nav li a {
    font-weight: bold;
    border: none;
    color: #fff;
}

ul.page-nav li, ul.page-nav li ul li {
    background-image: none;
    background-color: #000;
    opacity: 0.85;
    -moz-opacity: 0.85; /* older Gecko-based browsers */
    filter:alpha(opacity=85); /* For IE6&7 */
}

ul.page-nav li:hover,
ul.page-nav li.sfHover {
    border-bottom: 3px solid #999;
}

ul.page-nav li:hover,
ul.page-nav li.sfHover,
ul.page-nav a:focus, 
ul.page-nav a:hover, 
ul.page-nav a:active

{ 
    background: inherit;
    background-color: #999;
}

ul.page-nav ul a:focus, 
ul.page-nav ul a:hover, 
ul.page-nav ul a:active, 
ul.page-nav ul li.sfHover, 
ul.page-nav ul li:hover {
    background: none;
    border-bottom: none;
    background-color: #666;
    opacity: 70;
    -moz-opacity: 70; /* older Gecko-based browsers */
    filter:alpha(opacity=70); /* For IE6&7 */
}

.page-nav a, .page-nav a:visited {
    color: #fff;
    border: none;
}

.page-nav > li:hover > a > .sf-sub-indicator, .page-nav > li:active > a > .sf-sub-indicator,
.page-nav > li.sfHover > a > .sf-sub-indicator

{    
    background-image: url(/static/prophet/jquery/images/arrows-ffffff.png);
}


.page-nav > li > a > .sf-sub-indicator {    
    background-image: url(/static/prophet/jquery/images/arrows-cccccc.png);
}


.prop-summary {
    width: 80%;

}

 table.tablesorter tbody tr:nth-child(odd) td {
    background: #eee;
}




table.tablesorter tr:hover td,
table.tablesorter tr:nth-child(odd):hover td {
    background: #ffc;
}



dl.history dt {
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
dl.history dd {
    margin-bottom: 0.5em; 
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

ul.comments .creator, 
ul.comments .created{
}


ul.comments .creator:after {
    content: " wrote:";
}

ul.comments li .content {
    margin-top: 1em;
    white-space: pre;
    padding: 1em;
    font-size: 0.9em;
    overflow-x: auto;
}

ul.comments li:nth-child(odd) {
    background: #f5f5f5;
}

table.tablesorter {
    width: 100%;
    background: #fff;
    border: none;
    position: relative;
    display: block;
    border-collapse: collapse;
    border-spacing: 0;
}

table.tablesorter thead tr th, table.tablesorter tfoot tr th {
    padding-right: 2em;
}
table.tablesorter td {
    border-bottom: 1px solid #ccc;
}

table.tablesorter tbody td {
 color: #555;
 font-weight: bold;
 height: 4em;
 padding-top: 3em;

}

table.tablesorter td.summary {
 margin-top: 0em;
 padding: 0;
 padding-left: 0.25em;
 font-weight: normal;
 right:1em;
 overflow: hidden;
 margin-top: 0.75em;
 height: 1em;
 left: 3.75em;
 position: absolute;
 padding-bottom: 1.25em;
 border-bottom: none;

}

table.tablesorter td.summary a, table.tablesorter td.id a {
 font-size: 1.6em;
 text-decoration: none;
 color: #700;
}

table.tablesorter td.summary a {
 display: block;
 padding-bottom: 2em;
 right: 0;
 background: clear;
 z-index: 50;
}



table.tablesorter td.id  {
    padding-top: 1.5em;
    text-align: right;
    margin-right: em;
}
table.tablesorter td.id a {
    color: #bbb;
}

table.tablesorter td a:hover {
    text-decoration: underline;
}

' );
};

template '/' => page {'My open tickets for the current milestone'}
content {
    show('/tickets/hot');

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
    my $component = shift || '' ;

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


        
    $self->ticket_page_actions($ticket);

    form {

        my $f = function(
            record => $ticket,
            action => 'update',
            order => 1,
            name => 'edit-ticket'
        );

        div {  { class is 'ticket-props'};
        for my $prop ('summary') { 
            div { { class is "widget $prop"}; 
                    widget( function => $f, prop => $prop, autocomplete => 0 ) };
                    }

        for my $prop (qw(status component milestone)){
            div { { class is "widget $prop"}; 
                    widget( function => $f, prop => $prop ) };
        }
    
        div { class is 'other-props';
        for my $prop (@BASIC_PROPS) {
            next if $prop =~ /^(?:status|component|milestone|created)$/;

            div { { class is "widget $prop"}; 
                    widget( function => $f, prop => $prop ) };
        }
        }
        };
        div { class is 'submit';
        input { attr { value => 'Save', type => 'submit' } };
        };

        div { class is 'comment-form';
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

        };
        div { class is 'submit';
        input { attr { value => 'Save', type => 'submit' } };
        };
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
        div { class is 'ticket-props';
        for my $prop ('summary') {
            div {
                { class is "widget $prop" };
                widget( function => $f, prop => $prop, autocomplete => 0 );
            };
        }

        for my $prop (qw(status component milestone)){
            div { {class is 'widget '.$prop};
                 widget( function => $f, prop => $prop ) };

        }

        div { class is 'other-props';

        for my $prop (@BASIC_PROPS) {
            next if $prop =~ /^(?:status|component|milestone|created)$/;
            div { {class is 'widget '.$prop};
                 widget( function => $f, prop => $prop ) };
        }
        }
        };

        div { class is 'submit';
        input { attr { value => 'Save', type => 'submit' } };
        };


        div { class is 'comment-form';
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

        div { class is 'submit';
        input { attr { value => 'Save', type => 'submit' } };
        } 
        } 
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
    outs_raw($self->nav->render_as_menubar) if ($self->nav);
        div{ class is 'logowrapper';
        img { src is '/static/sd/images/sd.png';
              alt is 'SD Logo',
              class is 'logo' 
              };
              };
    div { class is 'project-name';
            " for ".$self->app_handle->setting( label => 'project_name' )->get()->[0]};
    h1 { $title };
};

template '/tickets/hot' => sub {
    my $self = shift;

    my $current_milestone = $self->app_handle->setting( label => 'default_milestone' )->get()->[0];

    $self->show_tickets(
        sub {
            my $item = shift;
            if (   $item->has_active_status
                && ( $item->prop('milestone') || '' ) eq $current_milestone
                && ( ( $item->prop('owner') || '' ) eq
                    $item->app_handle->config->get('email_address') || !$item->prop('owner') )
                )
            {
                return 1;
            } else {
                return undef;
            }
        }
    );

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
                th {'Milestone'};
                th {'Component'};
                th {'Owner'};
                th {'Reporter'};
                th {'Due'};
                th {'Created'};
            }
        };
        tbody {
            for my $ticket (@$tickets) {
                row {
                    cell { class is 'id'; ticket_link( $ticket => $ticket->luid ); };
                    for (@BASIC_PROPS) {
                    
                        cell { class is $_; $ticket->prop($_) };
                    }
                    cell { class is 'summary'; ticket_link( $ticket => $ticket->prop('summary') ); };
                }

            }
        };
    };
         script {outs_raw(qq{
            \$(document).ready(function() { \$("#@{[$id]}").tablesorter(); } ); 
        }

    );

     outs_raw('$("td.created,td.due").prettyDateTag();
 setInterval(function(){ $("td.created,td.due").prettyDateTag(); }, 5000);')
 };

        
        };

template 'show_ticket_history' => page {
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

        $self->ticket_page_actions($ticket);

        show ticket_history     => $ticket;
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

        $self->ticket_page_actions($ticket);


        show ticket_basics      => $ticket;
        show ticket_attachments => $ticket;
        show ticket_comments    => $ticket;

    };


sub ticket_page_actions {
    my $self = shift;
    my $ticket = shift;

    ul { {class is 'actions'};
        li { a {{ href is '/ticket/'.$ticket->uuid.'/view'}; 'Show'}; };
        li { a {{ href is '/ticket/'.$ticket->uuid.'/edit'}; 'Update'}; } unless($self->server->static);
        li { a {{ href is '/ticket/'.$ticket->uuid.'/history'}; 'History'}; };
    };


}


sub _by_creation_date { $a->prop('created') cmp $b->prop('created') };


private template 'ticket_basics' => sub {
    my $self = shift;
    my $ticket = shift;
        my %props = %{$ticket->get_props};
        div { { class is 'ticket-props'};
            div { class is 'widget uuid'; 
                label { 'UUID' };
            div { { class is 'value uuid'}; $ticket->uuid; } 
            };
        for my $key (@BASIC_PROPS, (sort keys %props)) {
            next unless defined $props{$key}; 
            next if ($key eq 'summary');
            next if ($key =~ /.{8}-.{4}-.{4}-.{12}-id/);
            div { class is 'widget '.$key;
                label {$key};
                div { { class is 'value ' . $key }; $props{$key}; }
            };

            delete $props{$key};

        }
        };

    script { outs_raw('$("div.created,div.due").prettyDateTag();
setInterval(function(){ $("div.created,div.due").prettyDateTag(); }, 5000);') };

};
template ticket_attachments => sub {
    my $self = shift;
    my $ticket = shift;


};
template ticket_history => sub {
    my $self = shift;
    my $ticket = shift;

   
    dl { { class is 'history'};
    for my $changeset  (sort {$a->created cmp $b->created}  $ticket->changesets) {
        dt {
                span { { class is 'created'};  $changeset->created };
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
    script { outs_raw('$("span.created").prettyDateTag();
setInterval(function(){ $("span.created").prettyDateTag(); }, 5000);') };
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
                    span {
                        { class is 'metadata' };
                        span { class is 'created'; $comment->prop('created') };
                         outs(" ");
                        span { class is 'creator';  $comment->prop('creator')};
                    }
                    div {
                        class is 'content';
                        $comment->prop('content') || i {'No body was entered for this comment'};
                    };
                }
            }
        }
    }
    script { outs_raw('$("span.created").prettyDateTag();
setInterval(function(){ $("span.created").prettyDateTag(); }, 5000);') };

};


sub ticket_link {
    my $ticket   = shift;
    my $label = shift;
    span {
        class is 'ticket-link';
        a {
            {
                class is 'ticket';
                href is '/ticket/' . $ticket->uuid."/view";
            };
            $label;
        }
    };
}
1;
