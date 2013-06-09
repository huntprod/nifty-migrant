use Nifty::Migrant;
# 001.first.pl

DEPLOY <<SQL;

	CREATE TABLE sample (
		id INTEGER PRIMARY KEY,
		value VARCHAR(10)
	);

SQL

ROLLBACK <<SQL;

	DROP TABLE sample;

SQL
