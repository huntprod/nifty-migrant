use Nifty::Migrant;
# 002.more-value.pl

DEPLOY <<SQL;

	ALTER TABLE sample RENAME TO tmp_sample;

	CREATE TABLE sample (
		id INTEGER PRIMARY KEY,
		value VARCHAR(010)
	);

	INSERT INTO sample (id, value)
		SELECT id, value FROM tmp_sample;

	DROP TABLE tmp_sample;

SQL

ROLLBACK <<SQL;

	ALTER TABLE sample RENAME TO tmp_sample;

	CREATE TABLE sample (
		id INTEGER PRIMARY KEY,
		value VARCHAR(10)
	);

	INSERT INTO sample (id, value)
		SELECT id, value FROM tmp_sample;

	DROP TABLE tmp_sample;

SQL
