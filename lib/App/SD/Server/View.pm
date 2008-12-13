use warnings;
use strict;

package App::SD::Server::View;
use base 'Prophet::Server::View';

use Template::Declare::Tags;
use Prophet::Server::ViewHelpers;

use App::SD::Model::Ticket;
use App::SD::Collection::Ticket;


template '/css/sd.css' => sub {

        outs_raw( '


body {
  font-family: sans-serif;
}

h1 {
    clear: both;
}
div.issue_list {

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
}

ul.page-nav a {

}


' );
};

template '/' => page {'SD'}
content {
    p {'sd is a P2P issue tracking system.'};
    show('milestone_list');
    show('/issues/open');

};

template 'milestones' => page {
    show 'milestone_list';
    }


template 'milestone_list' => sub {
    my $self = shift;
    my $milestones = $self->app_handle->setting( label => 'milestones' )->get();

    div { { class is 'pagesection'};
        h2 { 'Current milestones' };
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



template footer => sub { "SD $App::SD::VERSION - Issue tracking for the distributed age"};

template header => sub {
    my $self = shift;
    my $args = shift;
    my $title = shift @$args;
    outs_raw($self->nav->render_as_menubar);
    h1 { $title };
};


template '/issues/open' => sub {
    my $self = shift;
    h2 {'Open issues'};

    $self->show_issues (sub { my $item = shift; return $item->has_active_status ? 1 : 0; });

};

private template 'issue_list' => sub {
    my $self = shift;
    my $issues = shift;
    div {
        class is 'issue_list';
        
        for my $issue (@$issues) {
            ul {

                li {

                    issue_link( $issue => $issue->luid );
                    span { class is 'status';  $issue->prop('status') };
                    span { class is 'summary'; $issue->prop('summary') };
                    span { class is 'created'; $issue->prop('created') };

                }

            }

        }
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
        p {$issue->prop('summary')};


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
        dl { { class is 'issue-props'};
        for my $key (sort keys %$props) {
            dt{ $key };
            dd { $props->{$key}};
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
    my $self = shift;
    my $issue = shift;
    my @comments = sort _by_creation_date @{$issue->comments};
    if (@comments) {

        h2 { 'Comments'};

        ul {
        for my $comment (@comments) {
            li { 
span {
 $comment->prop('created') ." " .
$comment->prop('creator') }
blockquote { $comment->prop('content');};
        }
    }
    }}
 
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
