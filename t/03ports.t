#!/usr/bin/perl -w
use strict;

use Test::More tests => 2;
use Audio::LADSPA;

use strict;
my $plug = Audio::LADSPA->plugin( id => 1043);

ok($plug->isa("Audio::LADSPA::Plugin"),"loaded delay_5s/1043");

my @ports = $plug->ports;

ok(@ports == 4,"number of ports");


