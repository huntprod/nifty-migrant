use Nifty::Migrant;

DEPLOY <<SQL;

	ALTER TABLE sample ADD COLUMN col3 TEXT;

SQL

# no rollback
