use Nifty::Migrant;

DEPLOY <<SQL;

	ALTER TABLE sample ADD COLUMN col10 TEXT;

SQL

# no rollback
