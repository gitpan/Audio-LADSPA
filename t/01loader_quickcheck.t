#!/usr/bin/perl -w
use strict;
use Test::More tests => 6;

use strict;


BEGIN {
    use_ok('Audio::LADSPA');
}

ok(@Audio::LADSPA::LIBRARIES > 0,"some libraries loaded");

is( scalar(grep { $_ eq 'Audio::LADSPA::Library::delay' } Audio::LADSPA->libraries),1,"Audio::LADSPA::Library::delay loaded");

ok((scalar grep { $_ eq 'Audio::LADSPA::Plugin::XS::delay_5s_1043' } Audio::LADSPA->plugins) > 0,"Audio::LADSPA::Plugin::XS::delay_5s_1043 loaded"); 

ok(Audio::LADSPA->plugin( label => 'delay_5s' )->isa("Audio::LADSPA::Plugin"),"Plugin inheritance");

ok(Audio::LADSPA->plugin( name => 'Echo Delay Line (Maximum Delay 5s)')->isa("Audio::LADSPA::Plugin"),"Find by name");



