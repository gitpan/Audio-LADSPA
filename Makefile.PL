#!/usr/bin/perl -w
use strict;

our $VERSION = sprintf("%d.%03d", '$Name: v0_010-2004-06-28 $' =~ /(\d+)_(\d+)/,0,0);


warn <<GPL unless -f 'Makefile';
Audio::LADSPA v$VERSION
A collection of perl modules for interfacing with LADSPA plugins
Copyright (C) 2003  Joost Diepenmaat.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

See the COPYING file for more information.

GPL
use ExtUtils::MakeMaker;
use Config;

unless($ENV{LADSPA_PATH}) {
    warn <<WARN;
No LADSPA_PATH environment variable found, the Audio::LADSPA
modules assume '/usr/lib/ladspa:/usr/local/lib/ladspa', see
the README file for more information.
WARN
    $ENV{LADSPA_PATH} = '/usr/lib/ladspa:/usr/local/lib/ladspa';
}
else {
    my $found = 0;
    for (split/:/,$ENV{LADSPA_PATH}) {
	if (-f "$_/delay.$Config{so}") {
	    $found = 1;
	    last;
	}
    }
    unless ($found) {
	warn <<EOW;
------------------------------------------------------------
        the ladspa_sdk plugin "delay.$Config{so}" cannot be found
------------------------------------------------------------
 The tests specifically need the plugins from the
 ladspa_sdk package, with LADSPA_PATH pointing to the
 directory where they are installed.

 Please correct your LADSPA_PATH and/or download and 
 install the sdk from from http://www.ladspa.org/

 Alternatively, you can skip the tests, but these modules
 are of no use without at least SOME plugins installed.

 Proceed at your own risk. 
                                                The author.
------------------------------------------------------------
EOW
     sleep 2;
    }
}


WriteMakefile(
    'NAME'		=> 'Audio::LADSPA',
    'VERSION_FROM'	=> 'LADSPA.pm', # finds $VERSION
    'PREREQ_PM'		=> {
	'Test::More' => 0, 
	'Audio::Play' => 1.000, 
	'Audio::Data' => 1.000,
	'Graph::Directed' => 0,
	'Scalar::Util' => 0, 
    }, # e.g., Module::Name => 1.i
    
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
       (AUTHOR     => 'Joost Diepenmaat <joost AT hortus-mechanicus.net>') : ()),
    'EXE_FILES'		=> ['eg/pluginfo'],
    'OPTIMIZE'		=> '-O',
);

