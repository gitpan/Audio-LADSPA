#!/usr/bin/perl -w

use Test::More tests => 12;

use strict;
BEGIN {
    $|++;
    use_ok('Audio::LADSPA');
    use_ok('Audio::LADSPA::Plugin::Play');
}

my $buffer;
ok($buffer = Audio::LADSPA::Buffer->new(1),"buffer creation");

my $plugin;
ok($plugin = Audio::LADSPA->plugin( id => 1043 )->new(44100),"Plugin creation");

is($plugin->get_buffer('Delay (Seconds)'),undef,"Undef'd buffer");

ok($plugin->connect('Delay (Seconds)' => $buffer),"connecting");

is($plugin->get_buffer('Delay (Seconds)'),$buffer,"port->get_buffer");

eval {$plugin->run(100)};
ok($@ =~ /^Plugin not connected on all ports/,"Connection status checking");

ok ($plugin = Audio::LADSPA::Plugin::Play->new(44100),"perl plugin");

ok (!defined $plugin->get_buffer('Input'),"undef'd port");

ok($plugin->connect('Input' => $buffer),"connecting");

is($plugin->get_buffer('Input'),$buffer,"getting buffer");





