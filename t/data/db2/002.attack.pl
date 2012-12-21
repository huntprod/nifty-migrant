use Nifty::Migrant;
# 002.more-value.pl

DEPLOY <<SQL;

	DROP TABLE migrant_schema_info;

SQL

ROLLBACK <<SQL;

	CREATE TABLE migrant_schema_info (
		wrong_column INTEGER
	);

SQL
