use warnings;
use strict;

package App::SD::Server::View;
use Template::Declare::Tags;
use Prophet::Server::ViewHelpers;
use base 'Prophet::Server::View';

use App::SD::Model::Ticket;
use App::SD::Collection::Ticket;

template head => sub {
    my $self = shift;
    my $args = shift;
    head {
        title { shift @$args };
        show('style');
    }

};

template 'style' => sub {

    style {
        outs_raw( '
    body {
  font-family: sans-serif;
}

div.buglist {

 border: 1px solid grey;
  -moz-border-radius: 0.5em;
   -webkit-botder-radius: 0.5em;
   }

   div.buglist ul {
   list-style-type:none;

   }

   div.buglist ul li {
   clear: both;
   padding-bottom: 2em;
   border-bottom: 1px solid #ccc;
   margin-bottom: 1em;

 
   }

   

   div.buglist ul li span {

     float: left;
   padding: 0.2em;
     }

div.buglist ul li span.summary {
  width: 70%;

}

div.buglist ul li span.bug-link {
  width: 2em;
  text-align: right;
}

div.buglist ul li span.status {
   width: 3em;

}

' );
    }
};

template '/' => page {'SD'}
content {
    p {'sd is a P2P bug tracking system.'};
    show('/bugs/open');

};

template '/bugs/open' => sub {
    my $self = shift;
    my $bugs = App::SD::Collection::Ticket->new(
        app_handle => $self->app_handle,
        handle     => $self->app_handle->handle
    );
    $bugs->matching( sub { my $item = shift; 
         
    return $item->has_active_status ? 1 : 0; 
    
    });
    h2 {'Open bugs'};

    div {
        class is 'buglist';
        
        for my $bug (@$bugs) {
            ul {

                li {

                    bug_link( $bug => $bug->luid );
                    span { class is 'status';  $bug->prop('status') };
                    span { class is 'summary'; $bug->prop('summary') };
                    span { class is 'created'; $bug->prop('created') };

                }

            }

        }
    }
};

template '/show_bug' => page {

    } content {

    };

sub bug_link {
    my $bug   = shift;
    my $label = shift;
    span {
        class is 'bug-link';
        a {
            {
                class is 'bug';
                href is '/bug/' . $bug->uuid;
            };
            $label;
        }
    };
}
1;
