package App::SD::Server;
use base 'Prophet::Server';

sub css {
    return shift->SUPER::css(@_), "/static/sd/css/main.css";
}

sub js {
    return shift->SUPER::js(@_);
}
1;

