use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'		=> 'Audio::LADSPA::Plugin::Play',
    'VERSION_FROM'	=> 'Play.pm', # finds $VERSION
    'PREREQ_PM'		=> {'Test::More' => 0, 'Audio::Play' => 1 }, # e.g., Module::Name => 1.i
);

