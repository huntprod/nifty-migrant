package Nifty::Migrant;
use strict;
use warnings;

use Time::HiRes qw/gettimeofday/;
use Exporter ();
use base 'Exporter';
our @EXPORT = qw/DEPLOY ROLLBACK/;
our $VERSION = "1.0.0";

my $INFO = "migrant_schema_info";
my %STEPS = ();

sub parse_fname
{
	my ($file) = @_;
	my $s = $file;
	$s =~ s|.*/||;
	return (int($1), $2) if $s =~ m/^(\d+)\.(.*).pl$/;
	die "Failed to get schema version from '$file'\n";
}

sub register
{
	my ($number, $name, $deploy, $rollback) = @_;
	$STEPS{$number} = {
		this => int($number),
		name => $name,
	} unless exists $STEPS{$number};
	$STEPS{$number}{deploy} = $deploy if $deploy;
	$STEPS{$number}{rollback} = $rollback if $rollback;
}

sub clock(&)
{
	my ($sub) = @_;
	my $start = gettimeofday;
	$sub->();
	printf "     --> %0.3fs\n", gettimeofday - $start;
}

sub run_txn
{
	my ($db, $v, $sql) = @_;
	$db->do("BEGIN TRANSACTION")
		or die "Failed to start transaction: ".$db->errstr."\n";

	for (split /;\n\s+/, $sql) {
		s/--.*$//mg; s/\s+/ /mg;
		s/^\s*//; s/\s*$//;
		if (!$db->do($_)) {
			my $e = $db->errstr;
			$db->do("ROLLBACK TRANSACTION");
			die "SQL '$_': $e\n";
		}
	}

	my $st = $db->prepare("UPDATE $INFO SET version = ?");
	if (!$st or !$st->execute($v)) {
		my $e = $db->errstr;
		$db->do("ROLLBACK TRANSACTION");
		die "Failed to update schema version: $e\n";
	}
	$db->do("COMMIT TRANSACTION");
}

sub version
{
	my ($db) = @_;
	my $st = $db->prepare("SELECT version FROM $INFO");
	return unless $st and $st->execute;

	my $t = $st->fetchrow_hashref;
	return unless $t;
	return int($t->{version});
}

sub vname
{
	my ($v) = @_;
	return "latest" if ! defined $v;
	return "v$v" if $v > 0;
	return "initial";
}

sub run
{
	my ($db, $want, %opts) = @_;
	$opts{dir} = "db" unless $opts{dir};

	print STDERR "Running in NOOP mode... no database changes will be made\n"
		if $opts{noop};

	# load all the files
	opendir my $DH, $opts{dir}
		or die "Failed to list $opts{dir}/: $!\n";

	%STEPS = ();
	while (readdir($DH)) {
		next unless -f "$opts{dir}/$_" and m/\.pl/;
		do "$opts{dir}/$_";
	}
	closedir $DH;

	my $last = 0;
	for (sort keys %STEPS) {
		$STEPS{$_}{last} = $last;
		$last = $STEPS{$_}{this};
	}

	my $current = version($db);
	if (defined $current) {
		# sanity check against current version
		die "Database is at v$current; but migrations stop at v$last\n"
			if $current > $last;
	} else {
		$current = 0;
		unless ($opts{noop}) {
			$db->do("CREATE TABLE $INFO (version INTEGER);")
				or die "Failed to create $INFO table: ".$db->errstr."\n";
			$db->do("INSERT INTO $INFO (version) VALUES (0);")
				or die "Failed to set initial schema version: ".$db->errostr."\n";
		}
	}
	undef $last;

	# handle relative versions
	if (defined($want)) {
		$want += $current if $opts{relative} or $want < 0;
		$want = 0 if $want < 0;
	}
	my $final = $want;

	my $noop = ($opts{noop} ? "[NOOP] " : "");
	print ":: migrate from ".vname($current)." to ".vname($want)."\n";
	if (defined($want) and $current > $want) { # ROLLBACK!
		for (reverse sort keys %STEPS) {
			# skip the stuff we haven't deployed yet
			next if $_ > $current;

			# stop if we passed our target version
			last if $_ <= $want;

			# run the rollback!
			printf "::   %srollback %3i - %s\n", $noop, $_, $STEPS{$_}{name};
			if ($opts{verbose}) {
				print STDERR "-----------------------------------[ SQL ]------\n";
				print STDERR $STEPS{$_}{rollback};
			}
			clock { run_txn($db, $STEPS{$_}{last}, $STEPS{$_}{rollback}) } unless $opts{noop};
		}

	} else { # DEPLOY!
		my $n = 0;
		for (sort keys %STEPS) {
			# skip the stuff we've already deployed
			next if $_ <= $current;

			# stop if we passed our target version
			last if defined($want) and $_ > $want;

			# run the deploy!
			$final = $_;
			$n++;
			printf "::   %sdeploy %3i - %s\n", $noop, $_, $STEPS{$_}{name};
			if ($opts{verbose}) {
				print STDERR "-----------------------------------[ SQL ]------\n";
				print STDERR $STEPS{$_}{deploy};
			}
			clock { run_txn($db, $STEPS{$_}{this}, $STEPS{$_}{deploy}) } unless $opts{noop};
		}
		if ($n == 0) {
			print "Already at schema v$current\n";
			return 0;
		}
	}
	print ":: complete\n";
	unless ($opts{noop}) {
		my $vw = vname($want);
		my $vf = vname($final);
		print ":: current version: $vf".($vf ne $vw ? " ($vw)" : "")."\n";
	}
}

sub DEPLOY
{
	my ($sql) = @_;
	(undef, my $file) = caller;
	register(parse_fname($file), $sql, undef);
}

sub ROLLBACK
{
	my ($sql) = @_;
	(undef, my $file) = caller;
	register(parse_fname($file), undef, $sql);
}

1;

=head1 NAME

Migrant - Database Migration, all Rails-y

=head1 SUMMARY

Migrant provides a framework and a utility for managing a
single database schema as a set of migrations from one version
to the next, similar to the Ruby on Rails environment.

It is focused on staying out of the way, while not letting you
shoot yourself in the foot... too much.

=head1 FEATURES

=over

=item The Power of SQL

Migration code is nothing more than a set of SQL statements
that get executed in order to migrate, and another set of
SQL statements to rollback.  Since you can use all of the SQL
that your database backend supports, you can do data definition
changes (CREATE / DROP TABLE) as well as data manipulation
(SELECT / REPLACE INTO / UPDATE and friends).

=item The Flexibility of DBI

Built on a solid base of DBI, Migrant supports all the same
database backends that your local DBI installation does.

=item A Lil' Somethin' Extra for the Dancers

Migrant is built to work with the Dancer configuration file
format, and will figure out your DSN based on local configs.

=item Transactions

Each step of a deploy / rollback is wrapped in a transaction,
so if one of your SQL statements fails, the whole thing gets
rolled back, to protect the integrity of schema version
boundaries.

=back

=head1 MIGRATION STEPS

Migrant steps are pretty straightforward.  The template
generated by a `migrant new ...` should be enough:

    use Migrant;
    # 002.example.pl

    ###############################################################

    DEPLOY <<SQL;

      -- put your SQL statements here! --

    SQL

    ###############################################################

    ROLLBACK <<SQL;

      -- put your SQL statements here! --

    SQL

The B<DEPLOY> and B<ROLLBACK> functions register sets of
SQL statements to be run when this step (#2, 'example')
is deployed or reverted.

That's really all there is to it.  Cool, huh?

=head1 PUBLIC API

=head2 DEPLOY $SQL

Register I<$SQL> (a string) as statements to be run when
this step is deployed.  This is ignored outright during
rollback.

You should only have one call to B<DEPLOY> in each
migration step.

=head2 ROLLBACK $SQL

Register I<$SQL> (a string) to be run when this step is
rolled back.  This is ignored during deploy.

You really only need one call to B<ROLLBACK> for each step.

=head1 PRIVATE API

These functions are used to implement the internal guts
of Migrant, and are of no consequence to you unless you
want to A) hack on Migrant or B) B<reallly> understand
how it does what it does.

=head2 parse_fname($file)

Retrieve the step version and name of a step, as encoded
in the filename.  By convention, Migrant treats file names
in the form of NNN.zzz.pl as containing migration step
#NNN and a name of 'zzz'.

The step number and name will be returned as a list:

  my ($n, $s) = parse_fname("004.test.pl");
  # $n eq '004'
  # $s eq 'test'

parse_fname also handles full and relative path names:

  my ($n, $str) = parse_fname("db/001.init.pl");
  # $n = '001'
  # $s = 'init'

=head2 vname($version)

Returns a printable version string, treating '0' as "initial"
and undef as "latest".  This is used for the diagnostic output.

=head2 register($num, $name, $deploy_sql, $rollback_sql)

Register deploy and rollback SQL with a named and numbered
migration step.  This function rolls up the housekeeping
necessary to populate the %STEPS hash appropriately.
Subsequent calls will update an existing member of the STEPS
hash.

=head2 clock(\&code)

Run the passed sub, and time how long it took.  The final
time (in fractional seconds) will be printed to standard out.

=head2 run_txn($dbh, $v, $sql)

Runs B<$sql> against B<$dbh>, and update the internal schema
version to be at version B<$v>.  All work is done inside of
a transaction, and failures cause the transaction to be
properly rolled back.

=head2 version($dbh)

Get the current schema version from B<$dbh>.

=head2 run($dbh, $to_version, %opts)

Run necessary migration steps (either deploy or rollback)
until the schema reaches the wanted B<$to_version>.

Takes the following options:

=over

=item B<dir>

Directory that stores the migration files, relative to the
current working directory.  Defaults to 'db/'.

=item B<verbose>

Print the SQL statements as they are run.

=item B<noop>

Don't run the actual SQL statement, just show what would be
done based on current and desired schema versions.

=back

=head1 AUTHOR

Written by James Hunt <james@niftylogic.com>

=cut
