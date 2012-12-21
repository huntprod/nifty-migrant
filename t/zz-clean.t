#!perl
use strict;
use warnings;
use Test::More;

system("rm -rf t/tmp");
pass("cleanup");
done_testing;
