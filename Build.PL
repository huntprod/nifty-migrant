use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
	module_name         => 'Nifty::Migrant',
	license             => 'bsd',
	dist_author         => q{James Hunt <james@niftylogic.com>},
	dist_version_from   => 'lib/Nifty/Migrant.pm',
	configure_requires => {
		'Module::Build' => '0.38',
	},
	build_requires => {
		'Test::More'    => 0,
	},
	add_to_cleanup      => [ 'Nifty-Migrant-*' ]
);

$builder->create_build_script();
