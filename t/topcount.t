#!/usr/bin/env perl

use 5.026;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Data::Printer;

use Path::Tiny;

use VoteCount;
use VoteCount::ReadBallots 'read_ballots';

my $VC1 = VoteCount->new( ballotset => read_ballots('t/data/data2.txt'), );

my $tc1       = $VC1->TopCount();
my $expecttc1 = {
  CARAMEL    => 0,
  CHOCOLATE  => 1,
  MINTCHIP   => 5,
  PISTACHIO  => 2,
  ROCKYROAD  => 0,
  RUMRAISIN  => 0,
  STRAWBERRY => 0,
  VANILLA    => 7
};
is_deeply( $tc1, $expecttc1,
  "Topcounted a small set with no active list as expected" );

my $tc2       = $VC1->TopCount(
    { 'VANILLA' => 1, 'CHOCOLATE' => 1, 'CARAMEL' => 1,
      'PISTACHIO' => 0 });
my $expecttc2 = {
  CARAMEL    => 1,
  CHOCOLATE  => 1,
  PISTACHIO  => 2,
  VANILLA    => 7
};  is_deeply( $tc2, $expecttc2,
  "Topcounted a small set with AN active list as expected" );

done_testing();