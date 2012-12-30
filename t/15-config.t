#!perl
use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Nifty::Migrant::Config' };

{ # bad reads (corruption, ENOENT, etc.)
	my $config;
	my $file;

	$file = "file/that/doesnt/exist";
	ok(!-f $file, "$file should not be");
	$config = Nifty::Migrant::Config->read($file);
	ok(!$config, "Can't read from non-existent file");

	$file = "t/data/config/corrupt.yml";
	ok(-f $file, "$file exists");
	$config = Nifty::Migrant::Config->read($file);
	ok(!$config, "Can't read corrupt file");

	$file = "t/data/config/arrayref.yml";
	ok(-f $file, "$file exists");
	$config = Nifty::Migrant::Config->read($file);
	ok(!$config, "Can't read incorrect file");
}

{ # normal read / interrogation of config
	my $file = "t/data/config/basic.yml";
	ok(-f $file, "$file exists");
	my $config = Nifty::Migrant::Config->read($file);
	isa_ok($config, "Nifty::Migrant::Config",
		"got a Config object");

	# Uses DEVEL by default
	is($config->project, 'DEVEL', "Default project");
	is($config->environment, 'development', "Default environment");
	is($config->get('migrations'), "./db/",
		"use DEVEL 'migrations' key");
	is($config->get('config'), "./environments/development.yml",
		"expand %s with current environment in 'config' key");

	$config->environment('test');
	is($config->project, 'DEVEL', "Still using default project");
	is($config->environment, 'test', "Switched to test environment");
	is($config->get('config'), "./environments/test.yml",
		"expand %s with current environment in 'config' key");

	# Switch to production config
	$config->project('myproj');
	is($config->project, 'myproj', "Switched to 'myproj' project");
	is($config->get('migrations'), "/usr/share/myproj/db",
		"use named config for 'migrations' key");
	is($config->get('config'), "/etc/myproj/config.yml",
		"use named config for 'config' key");

	# Switch to incomplete config
	$config->project('incomplete');
	ok(!$config->get('missing'), "Missing key returns undef");

	# Switch to missing config
	$config->project('missing');
	ok(!$config->get('config'), "Missing config/key returns undef");
}

done_testing;
