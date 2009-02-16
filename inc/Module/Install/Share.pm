package Module::Install::Share;

use strict;
use Module::Install::Base;

use vars qw{$VERSION $ISCORE @ISA};
BEGIN {
	$VERSION = '0.79';
	$ISCORE  = 1;
	@ISA     = qw{Module::Install::Base};
}

sub install_share {
	my $self = shift;
	my $dir  = @_ ? pop   : 'share';
	my $type = @_ ? shift : 'dist';
	unless ( defined $type and $type eq 'module' or $type eq 'dist' ) {
		die "Illegal or invalid share dir type '$type'";
	}
	unless ( defined $dir and -d $dir ) {
		die "Illegal or missing directory install_share param";
	}

	# Split by type
	my $S = ($^O eq 'MSWin32') ? "\\" : "\/";
	if ( $type eq 'dist' ) {
		die "Too many parameters to install_share" if @_;

		# Set up the install
		$self->postamble(<<"END_MAKEFILE");
config ::
\t\$(NOECHO) \$(MOD_INSTALL) \\
\t\t"$dir" \$(INST_LIB)${S}auto${S}share${S}dist${S}\$(DISTNAME)

END_MAKEFILE
	} else {
		my $module = Module::Install::_CLASS($_[0]);
		unless ( defined $module ) {
			die "Missing or invalid module name '$_[0]'";
		}
		$module =~ s/::/-/g;

		# Set up the install
		$self->postamble(<<"END_MAKEFILE");
config ::
\t\$(NOECHO) \$(MOD_INSTALL) \\
\t\t"$dir" \$(INST_LIB)${S}auto${S}share${S}module${S}$module

END_MAKEFILE
	}

	# The above appears to behave incorrectly when used with old versions
	# of ExtUtils::Install (known-bad on RHEL 3, with 5.8.0)
	# So when we need to install a share directory, make sure we add a
	# dependency on a moderately new version of ExtUtils::MakeMaker.
	$self->build_requires( 'ExtUtils::MakeMaker' => '6.11' );

	# 99% of the time we don't want to index a shared dir
	$self->no_index( directory => $dir );
}

1;

__END__

=pod

=head1 NAME

Module::Install::Share - Install non-code files for use during run-time

=head1 SYNOPSIS

    # Put everything inside ./share/ into the distribution 'auto' path
    install_share 'share';

    # Same thing as above using the default directory name
    install_share;

=head1 DESCRIPTION

As well as Perl modules and Perl binary applications, some distributions
need to install read-only data files to a location on the file system
for use at run-time.

XML Schemas, L<YAML> data files, and L<SQLite> databases are examples of
the sort of things distributions might typically need to have available
after installation.

C<Module::Install::Share> is a L<Module::Install> extension that provides
commands to allow these files to be installed to the applicable location
on disk.

To locate the files after installation so they can be used inside your
module, see this extension's companion module L<File::ShareDir>.

=head1 TO DO

Currently C<install_share> installs not only the files you want, but
if called by the author will also copy F<.svn> and other source-control
directories, and other junk.

Enhance this to copy only files under F<share> that are in the
F<MANIFEST>, or possibly those not in F<MANIFEST.SKIP>.

=head1 AUTHORS

Audrey Tang E<lt>autrijus@autrijus.orgE<gt>

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 SEE ALSO

L<Module::Install>, L<File::ShareDir>

=head1 COPYRIGHT

Copyright 2006 Audrey Tang, Adam Kennedy.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
