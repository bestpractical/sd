use warnings;
use strict;

package App::SD::Server::View;
use Template::Declare::Tags;
use Prophet::Server::ViewHelpers;
use base 'Prophet::Server::View';

template '/' => 
    page    { 'SD' }
    content {
         p { 'sd is a P2P bug tracking system.' };

};

1;
