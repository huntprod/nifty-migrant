use Nifty::Migrant;
# 002.more-value.pl

DEPLOY <<SQL;

	CREAT TABLE test (
		id INTEGER PRIMARY KEY,
		name VARCHAR(200) NOT NURL UNIQUE
	);

SQL

ROLLBACK <<SQL;

	DORP TABLE test;

SQL
