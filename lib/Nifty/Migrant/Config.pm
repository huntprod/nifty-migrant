package Nifty::Migrant::Config;

use YAML;

sub read
{
	my ($class, $file) = @_;
	my $config = eval { YAML::LoadFile($file) };
	return unless $config and ref($config) eq 'HASH';
	bless({
			env    => 'development',
			proj   => 'DEVEL',
			config => $config
		}, $class);
}

sub environment
{
	my ($self, $value) = @_;
	$self->{env} = $value if defined $value;
	return $self->{env};
}

sub project
{
	my ($self, $value) = @_;
	$self->{proj} = $value if defined $value;
	return $self->{proj};
}

sub get
{
	my ($self, $key) = @_;
	return unless exists $self->{config}{$self->{proj}};
	my $val = $self->{config}{$self->{proj}}{$key};
	$val =~ s/%s/$self->{env}/g;
	$val;
}

1;

=head1 NAME

Nifty::Migrant::Config - Configuration Model for migrant

=head1 DESCRIPTION

The migrant utility reads in a global configuration file
(usually, /etc/migrant.yml) that contains a set of named
configuration trees.

This Module provides the backend implementation for reading
and interrogating this configuration file.

When a key is looked up, two extra pieces of information
are consulted: the B<project> and the B<environment>.

The B<project> determines which top-level hashref key to
look under.  By default, this is C<DEVEL>, to retain the
ease-of-use that migrant brings to development.

The B<environment> is used to as a text replacement for
the special characters '%s' in any found value.  This is
useful for Dancer configurations:

myapp:
  migrations:    /u/apps/myapp/db
  configuration: /etc/myapp/%s.yml

With the above configuration, myapp/devel would return
a configuration setting of C</etc/myapp/devel.yml>,
while an environment of test would give back
C</etc/myapp/test.yml>.

=head1 METHODS

=head2 read($file)

Reads a configuration file.  Returns undef if the file
cannot be read, or does not contain valid YAML.

    my $config = Nifty::Migrant::Config->read($file);

=head2 environment([$new])

Setter/getter for the currently active environment.

=head2 project([$new])

Setter/getter for the current project key.

=head2 get($key)

Retrieve a configuration value, according to current
project and environment.  Expands '%s' to the environment
name.

=head1 AUTHOR

Written by James Hunt <james@niftylogic.com>

=cut
