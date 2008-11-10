package App::SD::Server::Dispatcher;
use Prophet::Server::Dispatcher -base;

on qr/.*/ => sub {
    next_rule;
};

redispatch_to 'Prophet::Server::Dispatcher';


1;
