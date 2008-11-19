use inc::Module::Install;
name('sd');
author('Jesse Vincent and Chia-Liang Kao');
copyright('2008 Best Practical Solutions, LLC');
license('MIT');
version_from('lib/App/SD.pm');
requires('Time::Progress');
requires 'Prophet'; # URI UNIVERSAL::require Params::Validate Path::Class Class::Accessor Template::Declare::Tags Test::HTTP::Server::Simple JSON Test::WWW::Mechanize
requires('Moose'); # Moose::Role
requires('HTTP::Date');

features(
    'RT sync' => [
        -default => 0,
        'RT::Client::REST' => 0, # RT::Client::REST::Ticket

    ],

    'Hiveminder sync' => [
        -default => 0,
        'Net::Jifty' => 0.09,
        'Email::Address' => 0,
    ],
);

install_script('bin/sd');

# Include subdirectory tests too.
tests("t/*.t t/*/*.t");

auto_install();
&WriteAll;
