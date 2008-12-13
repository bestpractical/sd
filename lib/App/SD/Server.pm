package App::SD::Server;
use base 'Prophet::Server';

sub css {
    return shift->SUPER::css(@_), "/css/sd.css";
}

sub js {
    return shift->SUPER::js(@_);
}
1;

