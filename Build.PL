use strict;
use warnings;
use Module::Build;
use File::Find;

my %TREE;
sub tree_files { $TREE{$File::Find::name} = $File::Find::name if -f };
%TREE = (); find(\&tree_files, "etc"); my %ETC = %TREE;

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
	requires => {
		'YAML'          => 0,
		'DBI'           => 0,
		'Nifty::Config' => 0,
	},
	add_to_cleanup      => [
		'Nifty-Migrant-*',
		'cover_db',
		'*.rpm',
		'*.deb',
	],

	etc_files    => \%ETC,
	install_path => {
		etc => "etc"
	},
);

$builder->create_build_script();
$builder->add_build_element('etc');
