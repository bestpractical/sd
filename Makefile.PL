use inc::Module::Install;
name('App-SD');
author('Jesse Vincent and Chia-Liang Kao');
copyright('2008 Best Practical Solutions, LLC');
license('MIT');
version_from('lib/App/SD.pm');
requires('DateTime');
requires('DateTime::Format::ISO8601');
requires('Time::Progress');
requires('Path::Class');
requires 'Prophet'; # URI UNIVERSAL::require Params::Validate Class::Accessor Template::Declare::Tags Test::HTTP::Server::Simple JSON Test::WWW::Mechanize Any::Moose
requires('HTTP::Date');
requires('HTML::TreeBuilder');
requires('DateTime::Format::Natural');
requires('HTML::Tree');
requires('URI::file');
feature
    'RT sync' => 
        -default => 0,
        'RT::Client::REST' => 0, # RT::Client::REST::Ticket
;

feature    'Hiveminder sync' => 
        -default => 0,
        'Net::Jifty' => 0.09,
        'Email::Address' => 0;

install_script('bin/sd');
install_script('bin/git-sd');
install_share('share');

# Include subdirectory tests too.
tests("t/*.t t/*/*.t");

auto_install;
&WriteAll;
