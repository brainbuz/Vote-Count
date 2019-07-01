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

my $VC1 = Vote::Count->new( ballotset => read_ballots('t/data/data2.txt'), );

my $A1       = $VC1->Approval();
my $expectA1 = {
  CARAMEL    => 1,
  CHOCOLATE  => 8,
  MINTCHIP   => 8,
  PISTACHIO  => 2,
  ROCKYROAD  => 2,
  RUMRAISIN  => 1,
  STRAWBERRY => 5,
  VANILLA    => 10
};

is_deeply( $A1, $expectA1,
  "Approval counted for a small set with no active list" );

my $A2       = $VC1->Approval(
    { 'VANILLA' => 1, 'CHOCOLATE' => 1, 'CARAMEL' => 1,
      'PISTACHIO' => 0 });
my $expectA2 = {
  CARAMEL    => 1,
  CHOCOLATE  => 8,
  PISTACHIO  => 2,
  VANILLA    => 10
};

is_deeply( $A2, $expectA2,
  "Approval counted a small set with AN active list" );

done_testing();