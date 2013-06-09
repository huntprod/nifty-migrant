#!perl
use strict;
use warnings;
use Test::More;

BEGIN {
	use_ok "Nifty::Migrant";
}

##
## These tests are deliberately whitebox; they reach
## inside of the module for testing things that are
## vital to Migrant's operation
##


sub filename_ok
{
	my ($fname, $number, $name, $msg) = @_;
	$msg = "parse_fname($fname)" unless $msg;

	eval {
		my ($got_num, $got_name) = Nifty::Migrant::parse_fname($fname);
		pass("${msg}: parse_fname didn't die in eval");
		is($got_num,  $number, "${msg}: version number matches");
		is($got_name, $name,   "${msg}: step name matches");
	} or do {
		fail("${msg}: parse_fname failed to parse '$fname'");
	}
}

sub filename_not_ok
{
	my ($fname, $msg) = @_;
	$msg = ($msg ? "$msg: " : "");
	my ($got_num, $got_name);
	eval {
		($got_num, $got_name) = Nifty::Migrant::parse_fname($fname);
		fail("${msg}parse_fname('$fname') unexpectedly succeeded: ($got_num, $got_name)");
		1;
	} or do {
		pass("${msg}parse_fname failed as expected");
	}
}

{ # filename parsing
	filename_ok("001.init.pl", 1, "init");
	filename_ok("1.init.pl",   1, "init");
	filename_ok("012.last.pl", 12, "last");
	filename_ok("407.test.pl", 407, "test");
	filename_not_ok("001.pl");
	filename_not_ok("001.init.pm");
}

done_testing;
