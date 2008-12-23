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
    padding-left: 1em;
    padding-right: 1em;
    padding-bottom: 2em;
}

div.project-name {
    padding-top: 1em;
    font-style: italic;
    font-family: serif;
    
}

h1 {
    padding-top:  0.5em;
}

ul.issue_list {

 border: 1px solid grey;
  -moz-border-radius: 0.5em;
   -webkit-botder-radius: 0.5em;
   }

   div.issue_list ul {
   list-style-type:none;

   }

   div.issue_list ul li {
   clear: both;
   padding-bottom: 2em;
   border-bottom: 1px solid #ccc;
   margin-bottom: 1em;

 
   }

   

   div.issue_list ul li span {

     float: left;
   padding: 0.2em;
     }

table.tablesorter thead th {
color: #1133AA;
}
table.tablesorter thead tr .headerSortDown, table.tablesorter thead tr .headerSortUp, table.tablesorter thead tr th:hover {
    background-color: #ccc;
}
 th.headerSortUp,
 th.headerSortDown {
    background: #ccc;
}


div.issue_list ul li span.summary {
  width: 70%;

}

div.issue_list ul li span.issue-link {
  width: 2em;
  text-align: right;
}

div.issue_list ul li span.status {
   width: 3em;

}

ul.page-nav {
    float: right;
   margin-right: -1em;
}

ul.page-nav a {

}

textarea:focus, input:focus {
    background-color: #eec; 
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
    width: 6em;
    font-size: 0.8em;
    text-align: right;
    padding-right: 0.5em;
}
div.widget div.value {
    display: inline-block;
    

}
div.widget {
    padding: 0.5em;
}


ul.page-nav li {
    background: #ddd;
    border: 0;
}

ul.page-nav li:hover,
ul.page-nav li.sfHover,
ul.page-nav a:focus,
ul.page-nav a:hover, ul.page-nav a:active
{ 
    background: #ccc;
}

ul.page-nav {
    padding: 0;
    background: #601;

}

ul.page-nav a {
    border-top: 1px solid #eee;
}

' );
};

template '/' => page {'Open issues'}
content {
    show('/issues/open');

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

template 'milestone' => page { 'Milestone: '.$_[1] } content {
    my $self = shift;
    my $milestone = shift;

    h2 { 'Open issues for this milestone' } ;

    $self->show_issues(sub { (shift->prop('milestone')||'') eq $milestone}); 
    
    };

sub show_issues {
    my $self     = shift;
    my $callback = shift;

    my $issues = App::SD::Collection::Ticket->new(
        app_handle => $self->app_handle,
        handle     => $self->app_handle->handle
    );
    $issues->matching($callback);
    show( '/issue_list', $issues );
}

template edit_issue => page {

    my $self = shift;
        my $id = shift;
        my $issue = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $issue->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

       $issue->luid.": ".$issue->prop('summary');



} content {
    my $self = shift;
        my $id = shift;
        my $issue = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $issue->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

       title is $issue->luid.": ".$issue->prop('summary');

    ul { {class is 'actions'};
        li { a {{ href is '/issue/'.$issue->uuid.''}; 'Show'}; };
    };

    form {
        my $f = function(
            record => $issue,
            action => 'update',
            order => 1,
            name => 'edit-ticket'
        );
        for my $prop (
            'summary', 'status',  'owner',    'created',
            'due',     'creator', 'reporter', 'milestone'
            ) {

            div { { class is 'widget $prop'}; widget( function => $f, prop => $prop ) };
        }
        h2 { 'Comments' };

        my $c = function(
            record => App::SD::Model::Comment->new(     
                    app_handle => $self->app_handle ),
            action => 'create',
            order => 2,
            name => 'update-ticket-comment'
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
template new_issue => page {'Create a new ticket'} content {
    my $self = shift;

    form { { class is 'create-ticket'};

        my $f = function(
            record =>
                App::SD::Model::Ticket->new( app_handle => $self->app_handle ),
            action => 'create',
            order => 1,
            name => 'create-ticket'
        );
        for my $prop (
            'summary', 'status',  'owner',    'created',
            'due',     'creator', 'reporter', 'milestone'
            ) {

            div { {class is 'widget '.$prop};
                 widget( function => $f, prop => $prop ) };
        }
        h2 { 'Comments' };

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
    my @args = shift;
    my $title = shift @args;
    outs_raw($self->nav->render_as_menubar);
    div { class is 'project-name';
            "SD for ".$self->app_handle->setting( label => 'project_name' )->get()->[0]};
    h1 { $title };
};


template '/issues/open' => sub {
    my $self = shift;
    $self->show_issues (sub { my $item = shift; return $item->has_active_status ? 1 : 0; });

};

private template 'issue_list' => sub {
    my $self   = shift;
    my $issues = shift;
    my $id = substr(rand(10),2); # hack  to get a unique id
    table {
        { class is 'tablesorter'; id is $id; };
        thead {     
            row {
            th { 'id'};
            th {'Status'};
            th {'Summary'};
            th {'Created'};
            }
        };
        tbody {
        for my $issue (@$issues) {
            row {

                cell { issue_link( $issue => $issue->luid );};
                cell{ class is 'status';  $issue->prop('status') };
                cell { class is 'summary'; $issue->prop('summary') };
                cell { class is 'created'; $issue->prop('created') };

                }

            }
        };
        };
         script {outs_raw(qq{
            \$(document).ready(function() { \$("#@{[$id]}").tablesorter(); } ); 
        });
        }
        
        };

template 'show_issue' => page {
        my $self = shift;
        my $id = shift;
        my $issue = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $issue->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

       $issue->luid.": ".$issue->prop('summary');
    } content {
        my $self = shift;
        my $id = shift;
        my $issue = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $issue->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);
    ul { {class is 'actions'};
        li { a {{ href is '/issue/'.$issue->uuid.'/edit'}; 'Edit'}; };
    };

        show issue_basics      => $issue;
        show issue_attachments => $issue;
        show issue_comments    => $issue;
        show issue_history     => $issue;

    };


sub _by_creation_date { $a->prop('created') cmp $b->prop('created') };


private template 'issue_basics' => sub {
    my $self = shift;
    my $issue = shift;
        my $props = $issue->get_props;
        div { { class is 'issue-props'};
        for my $key (sort keys %$props) {
            div { class is 'widget'; 
                label{ $key };
            div { { class is 'value '.$key}; $props->{$key};
        
            } 
            }
        }
        };
};
template issue_attachments => sub {
    my $self = shift;
    my $issue = shift;


};
template issue_history => sub {
    my $self = shift;
    my $issue = shift;

   
    h2 { 'History'};
    
    ul {
    for my $changeset  (sort {$a->created cmp $b->created}  $issue->changesets) {
        li {
            ul { 
                li { $changeset->created. " ". $changeset->creator };
                li { $changeset->original_sequence_no. ' @ ' . $changeset->original_source_uuid };
            
                for my $change ($changeset->changes) {
                    next unless $change->record_uuid eq $issue->uuid;
                    li {
                        ul {
                            map { li {$_->summary} } $change->prop_changes;
                        };
                    }
                
            }
        }
    }
}
    };

};

template issue_comments => sub {
    my $self     = shift;
    my $issue    = shift;
    my @comments = sort  @{ $issue->comments };
    if (@comments) {
        h2 {'Comments'};
        ul {
            for my $comment (@comments) {
                li {
                    span { $comment->prop('created') . " " . $comment->prop('creator'); }
                    blockquote { $comment->prop('content'); };
                }
            }
        }
    }

};


sub issue_link {
    my $issue   = shift;
    my $label = shift;
    span {
        class is 'issue-link';
        a {
            {
                class is 'issue';
                href is '/issue/' . $issue->uuid;
            };
            $label;
        }
    };
}
1;
