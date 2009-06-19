use inc::Module::Install;
name('App-SD');
author('Jesse Vincent and Chia-Liang Kao');
copyright('2008-2009 Best Practical Solutions, LLC');
license('MIT');
version_from('lib/App/SD.pm');

requires 'Prophet'; # URI UNIVERSAL::require Params::Validate Class::Accessor Template::Declare::Tags Test::HTTP::Server::Simple JSON Test::WWW::Mechanize Any::Moose

requires('DateTime');
requires('Time::Progress');
requires('HTML::TreeBuilder');
requires('DateTime::Format::Natural');
requires('HTML::Tree');
requires('URI::file');


feature 'RT sync' => (
    -default => 0,
    'RT::Client::REST' => 0, # RT::Client::REST::Ticket
);

recommends 'RT::Client::REST';


feature 'Hiveminder sync' => (
    -default => 0,
    'Net::Jifty' => 0.09,
    'Email::Address' => 0,
);

recommends 'Net::Jifty';
recommends 'Email::Address';


feature 'Trac sync' => (
    -default => 0,
    'LWP::Simple' => 0,
    'Net::Trac' => 0.13,
);

recommends 'Net::Trac';

install_script('bin/sd');
install_script('bin/git-sd');
install_share('share');

# Include subdirectory tests too.
tests("t/*.t t/*/*.t");
extra_tests;
auto_install;
&WriteAll;
