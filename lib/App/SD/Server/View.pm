use warnings;
use strict;

package App::SD::Server::View;
use base 'Prophet::Server::View';

use Template::Declare::Tags;
use Prophet::Server::ViewHelpers;

use App::SD::Model::Ticket;
use App::SD::Model::Comment;
use App::SD::Collection::Ticket;


my @BASIC_PROPS = qw(status milestone component owner reporter due created tags description);

sub page_box { 
    my ($id, $title, $component) = (@_);

    div {   { id is $id };
            { h2 { $title}; show($component)}
        };

}

template '' => page { 'Project overview'} content {
    my $self = shift;
    div { { class is 'stats sidebar'};
    page_box('components', 'Components', 'component_list');
    page_box('statuses', 'Statuses', 'status_list');
    page_box('milestones', 'Milestones', 'milestone_list');
    };
    div { { class is 'overview'};
    h2 { 'Your active tickets for '. $self->app_handle->setting( label => 'default_milestone' )->get()->[0];};
    show('/tickets/hot');
    };
};

template 'hot_tickets' => page {'Your open tickets for the current milestone'}
content {
    show('/tickets/hot');

};

template 'all_tickets' => page {'All tickets'} content {
   shift->show_tickets( sub {1});
};

template 'milestones' => page {'Project milestones'} content {
    show 'milestone_list';
};


template 'status_list' => sub { show('property_list','status'); };
template 'milestone_list' => sub { show('property_list', 'milestone') };
template 'component_list' => sub { show('property_list', 'component')};

template 'property_list' => sub {
    my $self          = shift;
    my $property_name = shift;
    my $props         = $self->app_handle->setting(
        label => ( $property_name =~ /s$/ ? $property_name . "es" : $property_name . 's' ) )->get();

    my %counts = map { $_ => 0 } @$props;
    $self->find_tickets( sub {
             my $ticket = shift; 
            return if ($property_name ne 'status' && !$ticket->has_active_status);
            $counts{ $ticket->prop($property_name) || '' }++}); 

    my $total = 0;
    $total += $_ for values %counts;

    div {
        { class is 'pagesection' };
        ul {

            my @order = grep {$_ ne ''}  keys %counts;
                       
            if ( defined $counts{''} && $counts{''} > 0) {
                   push @order, '';
            }

 
            foreach my $prop ( @order) { 
                li {
                    div { {class is 'bar-wrapper'} ;
                        div {
                        { class is 'bar'; ($total ? style is ("width: ". int(( ($counts{$prop} ||0)/ $total) * 100 )."%") : ()) };
                        outs(' ');
                    };};
                        outs ( ($counts{$prop} ||'0') . " - ");
                    a {
                        { href is '/' . $property_name . '/' . ($prop ||'') }
                        ( $prop ? $prop : 'None' ) 
                    }

                }

            }
        }
    }

};




template 'status' => page { 'Status: ' . ( $_[1] || 'none' ) }
content {
    my $self      = shift;
    my $status = shift || '' ;

    $self->show_tickets(
        sub {my $item = shift;
            ( ( $item->prop('status') || '' ) eq $status )
                ? 1
                : 0;
        }
    );
};



template 'component' => page { 'Component: ' . ( $_[1] || 'none' ) }
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

template 'milestone' => page { 'Milestone: ' . ( $_[1] || 'none' ) }
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
    my $tickets = $self->find_tickets(@_);
    show( '/ticket_list', $tickets );
}

sub find_tickets {
    my $self     = shift;
    my $callback = shift;

    my $tickets = App::SD::Collection::Ticket->new(
        app_handle => $self->app_handle,
        handle     => $self->app_handle->handle
    );
    $tickets->matching($callback);
    return $tickets;
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
            next if $prop =~ /^(?:status|component|milestone|created|description)$/;

            div { { class is "widget $prop"}; 
                    widget( function => $f, prop => $prop ) };
        }
        }; 

            div { { class is "widget description"}; 
                    widget( function => $f, prop => 'description', type => 'textarea', autocomplete => 0) };

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
            next if $prop =~ /^(?:status|component|milestone|created|description)$/;
            div { {class is 'widget '.$prop};
                 widget( function => $f, prop => $prop ) };
        }

            div { {class is 'widget description'};
                 widget( function => $f, prop => 'description', type => 'textarea', autocomplete => '0' ) };

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
                    ( $item->app_handle->config->get(
                            key => 'user.email-address'
                        ) || '') || !$item->prop('owner') )
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
    div { { class is 'ticket-list'};
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
                    for (qw|status milestone component owner reporter due created|) {
                    
                        cell { class is $_; $ticket->prop($_) };
                    }
                    cell { class is 'summary'; ticket_link( $ticket => $ticket->prop('summary') ); };
                }

            }
        };
    }};
         script {outs_raw(qq{
            \$(document).ready(function() { \$("#@{[$id]}").tablesorter(); } ); 
        }

    );

     outs_raw('$("td.created,td.due").prettyDateTag();
 setInterval(function(){ $("td.created,td.due").prettyDateTag(); }, 5000);')
 };

        
        };

template 'history' => page {
    my $self = shift;
   'History';
}
content {
    my $self = shift;
    my $latest = $self->app_handle->handle->latest_sequence_no;
    my $start = shift || $latest;
    my $end = $start - 20;

    $end = 1 if $end < 1;

    my @changesets;
    $self->app_handle->handle->traverse_changesets(
        reverse  => 1,
        after    => $end,
        until    => $start,
        callback => sub {
            my %args = (@_);
            push @changesets, $args{changeset};
        }
    );

    div { { class is 'log'};
    my $nav = sub {
    div {{ class is 'nav'};
        if ($end > 1 ) {
            a {{  class is 'prev', href is '/history/'.($end-1) };  'Earlier'  };
        }
        if ($start < $latest) {
            a {{ class is 'next', href is '/history/'.(( $start+21 < $latest) ? ($start+21) : $latest) };  'Later'  };
        }
        }
    };

    $nav->();

    show(
        'format_history',
        changesets    => \@changesets,
        change_filter => sub {1},
        sort_changesets => sub { sort {$b->sequence_no <=> $a->sequence_no} @_ },
        change_header => sub {
            my $change = shift;
            if ( $change->record_type eq 'ticket' ) {
                my $ticket = App::SD::Model::Ticket->new(
                    app_handle => $self->app_handle,
                    handle     => $self->app_handle->handle
                );
                $ticket->load( uuid => $change->record_uuid );

                h2 {
                    a {{ href is '/ticket/' . $ticket->uuid; class is 'ticket-summary'; }; $ticket->prop('summary') };
                   span { { class is 'ticket-id'};  ' (' . ($ticket->luid || '') . ')'};
                }
            } elsif ($change->record_type eq 'comment') {
                my $ticket = App::SD::Model::Ticket->new(
                    app_handle => $self->app_handle,
                    handle     => $self->app_handle->handle
                );

                my $id;
                for ( $change->prop_changes ) {
                     if (  $_->name eq 'ticket' ) {  $id =  $_->new_value  }

                }

                return  unless ($id);
                $ticket->load( uuid =>  $id ) ;

                h2 {
                     outs('Comment on: ');
                     a {{ href is '/ticket/' . $ticket->uuid; class is 'ticket-summary'; }; $ticket->prop('summary') };
                   span { { class is 'ticket-id'};  ' (' . ($ticket->luid ||''). ')'};
                }


            }
        }
    );

    $nav->();
    }
};


template 'show_ticket_history' => page {
        my $self = shift;
        my $id = shift;
        my $ticket = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $ticket->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

       $ticket->luid.": ".($ticket->prop('summary') || '(No summary)');
    } content {
        my $self = shift;
        my $id = shift;
        my $ticket = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $ticket->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

        $self->ticket_page_actions($ticket);

        show('format_history', changesets => [$ticket->changesets], change_filter => sub { my $change = shift; return $ticket->uuid eq $change->record_uuid ? 1 : 0},
        
        );
        };

template 'show_ticket' => page {
        my $self = shift;
        my $id = shift;
        my $ticket = App::SD::Model::Ticket->new(
            app_handle => $self->app_handle,
            handle     => $self->app_handle->handle
        );
        $ticket->load(($id =~ /^\d+$/ ? 'luid' : 'uuid') =>$id);

       $ticket->luid.": ".($ticket->prop('summary') ||'(No summary)');
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
        for my $key (qw'status component milestone', 
                        (grep {$_ ne 'description'} (@BASIC_PROPS, (sort keys %props)))){
            next unless defined $props{$key}; 
            next if ($key =~ m{(?:summary)});
            next if ($key =~ /.{8}-.{4}-.{4}-.{12}-id/);
            div { class is 'widget '.$key;
                label {$key};
                div { { class is 'value ' . $key }; $props{$key}; }

            };
            delete $props{$key};
        
        };
        if ($props{description} ) {
            div { class is 'widget description';
                label {'description'};
                div { { class is 'value description' };
                        outs($props{description});
                }
            };
            }
    };
    script { outs_raw('$("div.created,div.due").prettyDateTag();
setInterval(function(){ $("div.created,div.due").prettyDateTag(); }, 5000);') };

};


template ticket_attachments => sub {
    my $self = shift;
    my $ticket = shift;


};





private template format_history => sub {
    my $self   = shift;
    my %args = (changesets => undef,
                change_filter => undef,
                change_header => undef,
                sort_changesets => sub { sort {$a->created cmp $b->created} @_ },
                @_);

    dl {
        { class is 'history' };
        for my $changeset ( $args{sort_changesets}->( @{$args{changesets}} )) {
            dt {
                span {
                    { class is 'created' };
                    $changeset->created;
                };
                span {
                    { class is 'creator' };
                    $changeset->creator || i {'Missing author'};
                };
                span { class is 'source_info';
                span {
                    { class is 'original_sequence_no' };
                    $changeset->original_sequence_no;
                };
                span {
                    { class is 'original_source_uuid' };
                    $self->app_handle->display_name_for_replica($changeset->original_source_uuid);
                };
                };
            };
            dd {
                for my $change ( $changeset->changes ) {
                    if ( $args{change_filter}->($change)) {
                    if ($args{change_header}) {
                        $args{change_header}->($change);
                    }
                    ul {

                        li { outs_raw($_) }
                        for (grep {$_}
                            map { show_history_prop_change($_) } ( $change->prop_changes ));
                    }
                    } else {
                        i { 'Something else changed - It was ' . $change->record_type . " ".$change->record_uuid};
                    }

                }
            }

        }
    };
    script {
        outs_raw(
            '$("span.created").prettyDateTag();
setInterval(function(){ $("span.created").prettyDateTag(); }, 5000);'
        );
    };
};

sub show_history_prop_change {
    my $pc = shift;
    if ( defined $pc->old_value && defined $pc->new_value ) {
        span { class is 'property'; $pc->name }
        . span { class is 'prose'; ' changed from ' }
            . span { class is 'value old'; $pc->old_value } . span { class is 'prose'; " to " }
            . span { class is 'value new'; $pc->new_value };
    } elsif ( defined $pc->new_value ) {
        span                { class is 'property';  $pc->name }
        . span { class is 'prose'; ' set to '} . span { class is 'value new'; $pc->new_value }

    } elsif ( defined $pc->new_value ) {
        span       { class is 'property';  $pc->name } . ' ' 
            . span { class is 'value old'; $pc->new_value } . span { class is 'prose'; ' deleted'};
    }
}

template ticket_comments => sub {
    my $self     = shift;
    my $ticket    = shift;
    my @comments = sort {$a->prop('created') cmp $b->prop('created')}  @{ $ticket->comments };
    if (@comments) {
        h2 { { class is 'conmments'};  'Comments'};
        ul {
            { class is 'comments' };
            for my $comment (@comments) {
                show('ticket_comment', $comment);

            }
        }
    script { outs_raw('$("span.created").prettyDateTag();
setInterval(function(){ $("span.created").prettyDateTag(); }, 5000);') };
    }

};

template ticket_comment => sub {
    my $self = shift;
    my $comment = shift;
                li {
                    span {
                        { class is 'metadata' };
                        span { class is 'created'; $comment->prop('created') };
                        outs(" ");
                        span { class is 'creator'; $comment->prop('creator') };
                    }
                    div {
                        class is 'content';
                        if ( !$comment->prop('content') ) {
                            i {'No body was entered for this comment'};

                        } elsif ( $comment->prop('content_type') &&  $comment->prop('content_type') =~ m{text/html}i ) {
                            outs_raw( $comment->prop('content') );
                        } else {
                            div { class is 'content-pre';     $comment->prop('content');};
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
                href is '/ticket/' . $ticket->uuid."/view";
            };
            $label;
        }
    };
}
1;
