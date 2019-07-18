#!/usr/bin/env perl

use 5.022;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Data::Printer;

use Path::Tiny;

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

my $VC1 = Vote::Count->new(
  BallotSet => read_ballots('t/data/data1.txt'), );

is(
  $VC1->BallotSetType(),
  'rcv',
  'BallotSetType option is set to rcv' );

is( $VC1->CountBallots(),
  10, 'Count the number of ballots in the set' );

done_testing();