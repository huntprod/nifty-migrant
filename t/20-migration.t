#!perl
use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;
use DBI;

BEGIN {
	system("rm -rf t/tmp && mkdir t/tmp");
	use_ok "Nifty::Migrant";
}

sub slurp
{
	my ($file) = @_;
	open my $fh, $file or BAIL_OUT("slurp($file): $!");
	my $stuff = do { local $/; <$fh> };
	close $fh;
	return $stuff;
}

sub is_output
{
	my ($actual, $expect) = @_;
	$actual =~ s/--> \d\.\d+s/--> X.XXs/g;
	$expect =~ s/--> \d\.\d+s/--> X.XXs/g;
	is($actual, $expect);
}

sub stdout_is
{
	is_output(slurp("t/tmp/stdout"), shift);
}

sub stderr_is
{
	is_output(slurp("t/tmp/stderr"), shift);
}

sub eval_ok
{
	my ($code, $msg) = @_;

	open my $stdout, ">&", \*STDOUT;
	open my $stderr, ">&", \*STDERR;
	open STDOUT, ">", "t/tmp/stdout";
	open STDERR, ">", "t/tmp/stderr";

	eval {
		$code->();
		open STDOUT, ">&", $stdout;
		open STDERR, ">&", $stderr;

		pass("$msg: did not die (as expected)");
		1;
	} or do {
		open STDOUT, ">&", $stdout;
		open STDERR, ">&", $stderr;

		fail("$msg: died '$@'");
	};
}

sub eval_not_ok
{
	my ($code, $regex, $msg) = @_;
	if (!$msg) {
		$msg = $regex;
		undef $regex;
	}

	open my $stdout, ">&", \*STDOUT;
	open my $stderr, ">&", \*STDERR;
	open STDOUT, ">", "t/tmp/stdout";
	open STDERR, ">", "t/tmp/stderr";

	eval {
		$code->();
		open STDOUT, ">&", $stdout;
		open STDERR, ">&", $stderr;

		fail("$msg: did not die");
		1;
	} or do {
		open STDOUT, ">&", $stdout;
		open STDERR, ">&", $stderr;

		pass("$msg: died (as expected)");
		like($@, $regex, "$msg: die message did not match") if $regex;
	};
}

sub temp_db
{
	(undef, my $DBFILE) = tempfile(UNLINK => 1);
	my $db = DBI->connect("dbi:SQLite:dbname=$DBFILE",
		undef, undef, { PrintError => 0, RaiseError => 0 });
	isa_ok($db, "DBI::db", "Got a DBI handle to work with");

	return $db;
}

{ # db1 : basic schema changes; no issues

	my $DIR = "t/data/db1";
	my $db = temp_db;

	ok(!defined(Nifty::Migrant::version($db)),
		"version number for empty DB is undefined");

	#### empty

	eval_ok(sub { Nifty::Migrant::run($db, undef, dir => $DIR, noop => 1) },
		"run(db, undef, noop => 1)");
	stdout_is <<EOF;
:: migrate from initial to latest
::   [NOOP] deploy   1 - first
::   [NOOP] deploy   2 - more-value
::   [NOOP] deploy   4 - skip
:: complete
EOF
	stderr_is <<EOF;
Running in NOOP mode... no database changes will be made
EOF
	ok(!defined(Nifty::Migrant::version($db)),
		"version number for empty DB after noop is undefined");

	#### empty

	eval_ok(sub { Nifty::Migrant::run($db, undef, dir => $DIR, verbose => 1) },
		"run(db, undef, %params)");
	stdout_is <<EOF;
:: migrate from initial to latest
::   deploy   1 - first
     --> X.XXs
::   deploy   2 - more-value
     --> X.XXs
::   deploy   4 - skip
     --> X.XXs
:: complete
:: current version: v4 (latest)
EOF
	stderr_is <<EOF;
-----------------------------------[ SQL ]------

	CREATE TABLE sample (
		id INTEGER PRIMARY KEY,
		value VARCHAR(10)
	);

	INSERT INTO sample (id, value) VALUES (1, "value 1");
	INSERT INTO sample (id, value) VALUES (2, "value 2");
	INSERT INTO sample (id, value) VALUES (3, "value 3");
	INSERT INTO sample (id, value) VALUES (4, "value 4");

------------------------------------------------
-----------------------------------[ SQL ]------

	ALTER TABLE sample RENAME TO tmp_sample;

	CREATE TABLE sample (
		id INTEGER PRIMARY KEY,
		value VARCHAR(010)
	);

	INSERT INTO sample (id, value)
		SELECT id, value FROM tmp_sample;

	DROP TABLE tmp_sample;

------------------------------------------------
-----------------------------------[ SQL ]------

	CREATE TABLE customers (
		id INTEGER PRIMARY KEY,
		name  VARCHAR(200),
		email VARCHAR(200),
		notes TEXT,
		class INTEGER
	);

	UPDATE sample SET value = "Second Value" WHERE id = 2;

------------------------------------------------
EOF
	is(Nifty::Migrant::version($db), 4,
		"run with no explicit version = deploy latest");

	#### v4

	eval_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR, noop => 1) },
		"run(db, 1, noop => 1)");
	stdout_is <<EOF;
:: migrate from v4 to v1
::   [NOOP] rollback   4 - skip
::   [NOOP] rollback   2 - more-value
:: complete
EOF
	stderr_is <<EOF;
Running in NOOP mode... no database changes will be made
EOF
	is(Nifty::Migrant::version($db), 4,
		"run(v1) still at v4 after noop rollback");

	#### v4

	eval_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR, verbose => 1) },
		"run(db, 1, %params)");
	stdout_is <<EOF;
:: migrate from v4 to v1
::   rollback   4 - skip
     --> X.XXs
::   rollback   2 - more-value
     --> X.XXs
:: complete
:: current version: v1
EOF
	stderr_is <<EOF;
-----------------------------------[ SQL ]------

	UPDATE sample SET value = "value 2" WHERE id = 2;

	DROP TABLE customers;

------------------------------------------------
-----------------------------------[ SQL ]------

	ALTER TABLE sample RENAME TO tmp_sample;

	CREATE TABLE sample (
		id INTEGER PRIMARY KEY,
		value VARCHAR(10)
	);

	INSERT INTO sample (id, value)
		SELECT id, value FROM tmp_sample;

	DROP TABLE tmp_sample;

------------------------------------------------
EOF
	is(Nifty::Migrant::version($db), 1,
		"run(v1) rolls back from v4 to v1");

	#### v1

	eval_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR, relative => 1) },
		"run(db, 1, relative => 1)");
	stdout_is <<EOF;
:: migrate from v1 to v2
::   deploy   2 - more-value
     --> X.XXs
:: complete
:: current version: v2
EOF
	stderr_is '';
	is(Nifty::Migrant::version($db), 2,
		"run(+1) deploys v1 to v2");

	#### v2

	eval_ok(sub { Nifty::Migrant::run($db, -1, dir => $DIR, relative => 1) },
		"run(db, -1, relative => 1)");
	stdout_is <<EOF;
:: migrate from v2 to v1
::   rollback   2 - more-value
     --> X.XXs
:: complete
:: current version: v1
EOF
	stderr_is '';
	is(Nifty::Migrant::version($db), 1,
		"run(-1) rolls back v2 to v1");

	#### v1

	eval_ok(sub { Nifty::Migrant::run($db, 2, dir => $DIR) },
		"run(db, 2, %params)");
	is(Nifty::Migrant::version($db), 2,
		"run(2) deploys v1 to v2");

	#### v2

	eval_ok(sub { Nifty::Migrant::run($db, 2, dir => $DIR) },
		"run(db, 2, %params)");
	is(Nifty::Migrant::version($db), 2,
		"run(2) is a noop");

	#### v2 (again)

	eval_ok(sub { Nifty::Migrant::run($db, -1, dir => $DIR) },
		"run(db, -1, %params)");
	is(Nifty::Migrant::version($db), 1,
		"run(-1) without relative option deploys v2 to v1");

	#### v1

	eval_ok(sub { Nifty::Migrant::run($db, -99, dir => $DIR) },
		"run(db, -99, %params)");
	is(Nifty::Migrant::version($db), 0,
		"run(-99) stops at v0");
}

{ # db2 : what if schema changes screw with migrant tables?
	my $DIR = "t/data/db2";
	my $db = temp_db;

	ok(!defined(Nifty::Migrant::version($db)),
		"version number for empty DB is undefined");

	#### empty

	eval_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR) },
		"run(db, 1, %params) [no relative]");
	is(Nifty::Migrant::version($db), 1,
		"run(1) is ok - no errors");

	#### v1

	eval_not_ok(sub { Nifty::Migrant::run($db, 2, dir => $DIR) },
		qr/no such table: migrant_schema_info at $0 line \d+\.?\n$/,
		"run(db, 2, %params)");
	is(Nifty::Migrant::version($db), 1,
		"run(2) fails by messing with migrant_schema_info");
}

{ # directory failure
	my $db = temp_db;

	ok(!-d "db", "db/ directory should not exist");

	# default dir should fail
	eval_not_ok(sub { Nifty::Migrant::run($db) },
		qr/failed to list db\/: no such file or directory at $0 line \d+/i,
		"run(db) with invalid default directory");
}

{ # db3 : what if the SQL is borked?
	my $DIR = "t/data/db3";
	my $db = temp_db;

	ok(!defined(Nifty::Migrant::version($db)),
		"version number for empty DB is undefined");

	#### empty

	eval_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR) },
		"run(db, 1, %params) [no relative]");
	is(Nifty::Migrant::version($db), 1,
		"run(1) is ok - no errors");

	#### v1

	eval_not_ok(sub { Nifty::Migrant::run($db, 2, dir => $DIR) },
		qr/SQL 'CREAT TABLE .*: syntax error at $0 line \d+\.?\n$/,
		"run(db, 2, %params)");
	is(Nifty::Migrant::version($db), 1,
		"run(2) fails due to bad SQL");
}

{ # db4 - lots of migrations (over 10!)
  # tickled a string/integer sorting bug

	qx(rm -rf t/tmp/db4; /bin/cp -a t/data/db4 t/tmp/db4);

	my $DIR = "t/tmp/db4";
	my $db = temp_db;
	ok(!defined(Nifty::Migrant::version($db)),
		"new database has undefined schema version");

	eval_ok(sub { Nifty::Migrant::run($db, undef, dir => $DIR) },
		"migrate to v12");
	is(Nifty::Migrant::version($db), 12, "migrated to v12");
}

{ # version against bad migrant_schema_info table
	my $db = temp_db;
	ok(!defined(Nifty::Migrant::version($db)),
		"new database has undefined schema version");

	$db->do("CREATE TABLE migrant_schema_info (vnumber INTEGER)");
	ok(!defined(Nifty::Migrant::version($db)),
		"invalid migrant_schema_info table -> undefined version");

	$db->do("DROP TABLE migrant_schema_info");
	$db->do("CREATE TABLE migrant_schema_info (version INTEGER)");
	ok(!defined(Nifty::Migrant::version($db)),
		"empty migrant_schema_info table -> undefined version");
}

{ # tool-19: what if the database is at v3, but we only
  # have v1 and v2 defined on-disk

	qx(rm -rf t/tmp/db1; /bin/cp -a t/data/db1 t/tmp/db1);

	my $DIR = "t/tmp/db1";
	my $db = temp_db;
	ok(!defined(Nifty::Migrant::version($db)),
		"new database has undefined schema version");

	eval_ok(sub { Nifty::Migrant::run($db, undef, dir => $DIR) },
		"migrate to v4");
	is(Nifty::Migrant::version($db), 4, "migrated to v4");

	# delete the v4 migration
	unlink "t/tmp/db1/004.skip.pl";

	eval_not_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR) },
		qr/^Database is at v4; but migrations stop at v2 at $0 line \d+\.?\n?$/,
		"rollback to v1 (which should fail)");
	is(Nifty::Migrant::version($db), 4, "still at v4");
}

done_testing;
