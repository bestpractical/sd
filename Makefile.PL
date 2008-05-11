use inc::Module::Install;
name('sd');
author('Jesse Vincent and Chia-Liang Kao');
copyright('2008 Best Practical Solutions, LLC');
license('MIT');
version_from('lib/App/SD.pm');

requires 'Prophet'; # URI UNIVERSAL::require Params::Validate Path::Class Class::Accessor
requires 'RT::Client::REST'; # RT::Client::REST::Ticket
requires 'DateTime::Format::HTTP';

features(
    'Hiveminder sync' => [
        -default => 1,
        recommends('Jifty'),
    ],
);

&WriteAll;
