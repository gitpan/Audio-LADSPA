#!/usr/bin/perl -w
use strict;

use Test::More tests => 7;
use Audio::LADSPA;

use strict;
my $plug = Audio::LADSPA->plugin( id => 1043);

ok($plug->isa("Audio::LADSPA::Plugin"),"loaded delay_5s/1043");

my $object= $plug->new(44100);

ok(ref($object) and $object->isa("Audio::LADSPA::Plugin"),"object instantiation");

my $objectref2 = $object;

is("$object", "$objectref2","Object copies have same stringification");

is($object->sessionid,$objectref2->sessionid,"Object copies have same sessionids");

$objectref2 = $plug->new(44100);

ok("$object" ne "$objectref2","Different objects have different stringification");

ok($object->sessionid =~ /^0x[a-f0-9]+$/,"Session id format");



ok($object->sessionid ne $objectref2->sessionid,"Session ids differ for different objects");

