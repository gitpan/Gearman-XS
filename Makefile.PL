use 5.006000;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME			=> 'Gearman::XS',
	VERSION_FROM	=> 'lib/Gearman/XS.pm',
	PREREQ_PM		=> {'Test::More' => 0, 'Storable' => 0},
	ABSTRACT		=> 'This is a Perl front end for the Gearman C library. It aims to provide a simple interface closely tied to the C library',
	AUTHOR			=> 'Dennis Schoen <dennis@blogma.de>',
	LIBS			=> ['-lgearman'],
);