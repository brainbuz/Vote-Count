#!/usr/bin/env perl

use 5.026;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
# use Data::Printer;

use Path::Tiny;

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

my $VC1 = Vote::Count->new(
  ballotset => read_ballots('t/data/data1.txt'), );

is(
  $VC1->ballotsettype(),
  'rcv',
  'ballotsettype option is set to rcv' );

done_testing();