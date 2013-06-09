use Nifty::Migrant;

DEPLOY <<SQL;

	ALTER TABLE sample ADD COLUMN col11 TEXT;

SQL

# no rollback
