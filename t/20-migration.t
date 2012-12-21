#!perl
use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;
use DBI;

BEGIN {
	use_ok "Nifty::Migrant";
}

sub eval_ok
{
	my ($code, $msg) = @_;
	eval {
		$code->();
		pass("$msg: did not die (as expected)");
		1;
	} or do {
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
	eval {
		$code->();
		fail("$msg: did not die");
		1;
	} or do {
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
	ok(!defined(Nifty::Migrant::version($db)),
		"version number for empty DB after noop is undefined");

	#### empty

	eval_ok(sub { Nifty::Migrant::run($db, undef, dir => $DIR, verbose => 1) },
		"run(db, undef, %params)");
	is(Nifty::Migrant::version($db), 4,
		"run with no explicit version = deploy latest");

	#### v4

	eval_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR, noop => 1) },
		"run(db, 1, noop => 1)");
	is(Nifty::Migrant::version($db), 4,
		"run(v1) still at v4 after noop rollback");

	#### v4

	eval_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR, verbose => 1) },
		"run(db, 1, %params)");
	is(Nifty::Migrant::version($db), 1,
		"run(v1) rolls back from v4 to v1");

	#### v1

	eval_ok(sub { Nifty::Migrant::run($db, 1, dir => $DIR, relative => 1) },
		"run(db, 1, relative => 1)");
	is(Nifty::Migrant::version($db), 2,
		"run(+1) deploys v1 to v2");

	#### v2

	eval_ok(sub { Nifty::Migrant::run($db, -1, dir => $DIR, relative => 1) },
		"run(db, -1, relative => 1)");
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
		qr/no such table: migrant_schema_info\n$/,
		"run(db, 2, %params)");
	is(Nifty::Migrant::version($db), 1,
		"run(2) fails by messing with migrant_schema_info");
}

{ # directory failure
	my $db = temp_db;

	ok(!-d "db", "db/ directory should not exist");

	# default dir should fail
	eval_not_ok(sub { Nifty::Migrant::run($db) },
		qr/failed to list db\/: no such file or directory/i,
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
		qr/SQL 'CREAT TABLE .*: syntax error\n$/,
		"run(db, 2, %params)");
	is(Nifty::Migrant::version($db), 1,
		"run(2) fails due to bad SQL");
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

done_testing;
