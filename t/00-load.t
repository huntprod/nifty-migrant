#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Nifty::Migrant' ) || print "Bail out!\n";
}

diag( "Testing Nifty::Migrant $Nifty::Migrant::VERSION, Perl $], $^X" );
