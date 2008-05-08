use inc::Module::Install;
name('sd');
author('Jesse Vincent and Chia-Liang Kao');
copyright('2008 Best Practical Solutions, LLC');
license('MIT');
version_from('lib/App/SD.pm');

requires 'Prophet';

&WriteAll;
