#!/usr/bin/perl -w
use strict;

use Test::More tests => 12;

BEGIN {
    use_ok('Audio::LADSPA::Network');
    use_ok('Audio::LADSPA::Plugin::Play');
}

my $net = Audio::LADSPA::Network->new( buffer_size => 100 );
ok($net,"instantiation");
my $sine = $net->add_plugin( id => 1047);
ok($sine,"add sine plugin");

my $delay = $net->add_plugin( id => 1043);
ok($delay,"add delay plugin");

my $play = $net->add_plugin( 'Audio::LADSPA::Plugin::Play' );
ok ($play,"add player");

ok($net->connect($sine,'Output', $delay, 'Input'),"connection ok");

ok($net->connect($delay,'Output', $play, 'Input'),"connection ok2");

is($delay->get_buffer('Output'),$play->get_buffer('Input'),"really connected");

is($sine->get('Frequency (Hz)'),440,"Default value");
$sine->set(Amplitude => 1);   # set amp


$delay->set('Delay (Seconds)' => 0.5);
$delay->set('Dry/Wet Balance' => 0.2);

ok(1,"set smoke");

my $f = 110;
for (0 .. 1000) {
  $sine->set('Frequency (Hz)' => $f);
  $_ % 100 or $f *= 1.25;
  $net->run(100);
}
$sine->get_buffer(1)->set_1(0); # silence sine wave

for (0 .. 1000) {
  $net->run(100);
}


SKIP: {
#    skip("No audio output",1) unless $p;
    print STDERR "You should have heard some rising tones, with one 0.5 second echo\n";
    print STDERR "Did it work? [Y]";
    my $y = <STDIN>;
    chomp($y);
    ok($y eq '' or $y =~ /y/i,"Sounds ok!");
}


    

