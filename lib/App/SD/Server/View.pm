use warnings;
use strict;

package App::SD::Server::View;
use Template::Declare::Tags;
use Prophet::Server::ViewHelpers;
use base 'Prophet::Server::View';

    use App::SD::Model::Ticket;
    use App::SD::Collection::Ticket;


template '/' => 
    page    { 'SD' }
    content {
         p { 'sd is a P2P bug tracking system.' };

    show('/bugs/open');

};


template '/bugs/open' => sub {
    my $self = shift;
    my $bugs = App::SD::Collection::Ticket->new( app_handle => $self->app_handle, handle     => $self->app_handle->handle);
    $bugs->matching( sub { my $item = shift; return $item->prop('status') ne 'closed'  ? 1 : 0; } );


    h2 { 'Open bugs' };

    for my $bug (@$bugs) {
    ul {
    
        li {


            bug_link($bug => $bug->luid);
            span { $bug->prop('status') };
            span { $bug->prop('summary') };
            span { $bug->prop('created') };

        }

    }

        }

};


template '/show_bug' => page {
    

} content {


};


sub bug_link {
        my $bug = shift;
        my $label = shift;
        a {{ class is 'bug';
            href is '/bug/'.$bug->uuid; };
            $label;
        };
    } 
1;
