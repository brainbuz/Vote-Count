#!/usr/bin/env perl
# HARNESS-NO-PRELOAD
# HARNESS-CAT-LONG
# THIS IS A GENERATED YATH RUNNER TEST
use strict;
use warnings;

use App::Yath::Util qw/find_yath/;

system($^X, '-Ilib', find_yath(), 'test', '--default-search' => './t', '--default-search' => './t2', @ARGV);
my $exit = $?;

# This makes sure it works with prove.
print "1..1\n";
print "not " if $exit;
print "ok 1 - Passed tests when run by yath\n";
print STDERR "yath exited with $exit" if $exit;

exit($exit ? 255 : 0);
