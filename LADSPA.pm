# Audio::LADSPA perl modules for interfacing with LADSPA plugins
# Copyright (C) 2003  Joost Diepenmaat.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# See the COPYING file for more information.

package Audio::LADSPA;
use strict;
use Audio::LADSPA::LibraryLoader;
use Audio::LADSPA::Buffer;
use 5.006;
use Carp;

our $VERSION = sprintf("%d.%03d", '$Name: v0_009-2004-01-02 $' =~ /(\d+)_(\d+)/,0,0);

our @LIBRARIES;	    # will store the list of found libraries as Perl class names
our @PLUGINS;	    # will store the names of all loaded plugins as Perl class names
our %PLUGINS;	    # will store the values in @PLUGINS indexed by id

unless (@LIBRARIES) {
    for my $lib_path (Audio::LADSPA::LibraryLoader->find_libraries()) {
	Audio::LADSPA->load($lib_path);
    }
}

sub load {
    my ($class,$lib_path) = @_;
    my $lib = Audio::LADSPA::LibraryLoader->load($lib_path);
    push @LIBRARIES,$lib;
    for ($lib->plugins()) {
	push @PLUGINS,$_;
	$PLUGINS{ $_->id } = $_;
    }
    return $lib;
}


sub libraries {
    @LIBRARIES,'Audio::LADSPA::Library::Perl';
}

sub plugins {
    @PLUGINS;
}

sub plugin {
    shift;
    (my (%args) = @_) or croak "usage: Audio::LADSPA::Plugin->( find_args )";
    if ($args{id}) {
        return $PLUGINS{$args{id}};
    }
    else {
	for (@PLUGINS) {
	    if ($args{label}) {
		next unless $_->label eq $args{label};
	    }
	    if ($args{name}) {
		next unless $_->name eq $args{name};
	    }
	    return $_;
	}
    }
}

END {
    for (@LIBRARIES) {
	Audio::LADSPA::LibraryLoader->unload($_);
    }
}

1;

__END__

=head1 NAME

Audio::LADSPA - Perl extension for processing audio streams using LADSPA plugins.

=head1 SYNOPSIS

    use Audio::LADSPA;

    for my $class (Audio::LADSPA->plugins) {
	print "\t",$class->name," (",$class->id,"/",$class->label,")";
    }


=head1 DESCRIPTION

This module starts up a LADSPA 1.1 host environment as a perl extension
you can use it to query LADSPA plugins, and to apply plugins to
audio streams. 

=head1 USER GUIDE

This is the reference documentation.  If you want a general 
overview/introduction on this set of modules, take a look at 
L<Audio::LADSPA::UserGuide>. 

=head1 STARTUP

By default, C<use Audio::LADSPA> will attempt to load all
libraries in the $ENV{LADSPA_PATH} (a colon seperated list
of directories) or "/usr/lib/ladspa" and "/usr/local/lib/ladspa" if
$ENV{LADSPA_PATH} is not set.

You can then get the loaded libraries and their plugins using
the C<libraries>, C<plugins> and C<plugin> methods described below.

=head1 METHODS

All methods in the Audio::LADSPA package are class methods.

=head2 plugins

    my @availabe_plugins = Audio::LADSPA->plugins();

Returns the list of @available_plugins. These are package names
you can use to create a new instance of those plugins, can invoke
class-methods on to query the plugins, and pass to Audio::LADSPA::Network
to do most of the work for you. See also L<Audio::LADSPA::Plugin> and
L<Audio::LADSPA::Network>.

=head2 plugin

    my $plugin = Audio::LADSPA->plugin( %search_arguments );

Get the package name (class) for a specific Audio::LADSPA::Plugin
subclass given the %search_arguments. Returns the I<first matching>
plugin class or C<undef> if none is found. You can use one or
less of each of these:

=head3 id

    my $sine_faaa_class = Audio::LADSPA->plugin( id => 1044 );

Match a plugin class by unique id. If one is loaded returns the class
name. If an C<id> argument is present, other %search_arguments will
not be considered.

=head3 label

    my $delay_5s = Audio::LADSPA->plugin( label => 'delay_5s' );

Match a plugin class by C<label>. If C<name> is also specified,
the plugin must also match C<name>.

=head3 name

    my $noise = Audio::LADSPA->plugin( name => 'White Noise Source' );

Match a plugin class by C<name>. If C<label> is also specified,
the plugin must also match C<label>.

=head2 libraries

    my @loaded_libraries = Audio::LADSPA->libraries();

Returns the list of @loaded_libraries (Audio::LADSPA::Library subclasses),
mostly useful if you want to know which plugins are in a specific library.

See also L<Audio::LADSPA::Library>.

=head2 

=head1 SEE ALSO

L<Audio::LADSPA::UserGuide> - the user guide.

=head2 Modules and scripts in this distribution

L<pluginfo> - query ladspa plugins.

L<Audio::LADSPA::Library> - a libraries containing one
or more plugins

L<Audio::LADSPA::Plugin> - the actual ladspa plugins 

L<Audio::LADSPA::Buffer> - audio/data buffer that can be used to control
a plugin or to connect plugins together

L<Audio::LADSPA::Network> - a set of connected plugins and buffers

L<Audio::LADSPA::LibraryLoader> - loads ladspa shared libraries (.so files) into
Audio::LADSPA::Library classes

=head2 Links

For more information about the LADSPA API, and how to obtain more plugins, see 
http://www.ladspa.org/

The website for these modules is located at:
http://www.hortus-mechanicus.net/perl/

=head1 THANKS TO

=over 4

=item * Mike Castle, for providing a patch for non-C'99 compilers.

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003 Joost Diepenmaat <joost AT hortus-mechanicus.net>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

