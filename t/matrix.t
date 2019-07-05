#!/usr/bin/env perl

use 5.026;

# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Data::Printer;
use feature qw /postderef signatures/;

use Path::Tiny;

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

my $M1 = Vote::Count->new(
  ballotset  => read_ballots('t/data/data1.txt'),
);

can_ok( $M1,
  [qw/Populate/],
  "expected subs for a matrix");


# p $M1->TieBreakTable();

$M1->Populate();
# p $M1->{'Matrix'};

done_testing();