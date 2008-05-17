use inc::Module::Install;
name('sd');
author('Jesse Vincent and Chia-Liang Kao');
copyright('2008 Best Practical Solutions, LLC');
license('MIT');
version_from('lib/App/SD.pm');

requires 'Prophet'; # URI UNIVERSAL::require Params::Validate Path::Class Class::Accessor
requires('Clone');
features(
    'RT sync' => [
        -default => 1,
        'RT::Client::REST' => 0, # RT::Client::REST::Ticket
        'DateTime::Format::HTTP' => 0,

    ],

    'Hiveminder sync' => [
        -default => 1,
        'Net::Jifty' => 0,
        'Jifty' => 0,
    ],
);
auto_install();
&WriteAll;
