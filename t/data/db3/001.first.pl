use Nifty::Migrant;
# 001.first.pl

DEPLOY <<SQL;

	CREATE TABLE sample (
		id INTEGER PRIMARY KEY,
		value VARCHAR(10)
	);

	INSERT INTO sample (id, value) VALUES (1, "value 1");
	INSERT INTO sample (id, value) VALUES (2, "value 2");
	INSERT INTO sample (id, value) VALUES (3, "value 3");
	INSERT INTO sample (id, value) VALUES (4, "value 4");

SQL

ROLLBACK <<SQL;

	DROP TABLE sample;

SQL
