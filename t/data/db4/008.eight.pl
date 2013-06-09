use Nifty::Migrant;

DEPLOY <<SQL;

	ALTER TABLE sample ADD COLUMN col8 TEXT;

SQL

# no rollback
