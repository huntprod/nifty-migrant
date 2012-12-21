use Nifty::Migrant;
# 004.skip.pl

DEPLOY <<SQL;

	CREATE TABLE customers (
		id INTEGER PRIMARY KEY,
		name  VARCHAR(200),
		email VARCHAR(200),
		notes TEXT,
		class INTEGER
	);

	UPDATE sample SET value = "Second Value" WHERE id = 2;

SQL

ROLLBACK <<SQL;

	UPDATE sample SET value = "value 2" WHERE id = 2;

	DROP TABLE customers;

SQL
