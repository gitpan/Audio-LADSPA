#!/usr/bin/perl -w
use strict;
use Test::More tests => 3;

use strict;


BEGIN {
    use_ok('Audio::LADSPA');
}

SKIP: {
    ok(@Audio::LADSPA::LIBRARIES > 0,"some libraries loaded");

    ok(Audio::LADSPA->plugin( label => 'delay_5s' )->isa("Audio::LADSPA::Plugin"),"Plugin inheritance");
};



