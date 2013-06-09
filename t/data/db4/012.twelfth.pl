use Nifty::Migrant;

DEPLOY <<SQL;

	ALTER TABLE sample ADD COLUMN col12 TEXT;

SQL

# no rollback
