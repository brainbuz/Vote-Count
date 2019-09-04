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
use Vote::Count::ReadBallots 'read_ballots', 'read_range_ballots';

my $VC1 = Vote::Count->new( BallotSet => read_ballots('t/data/data2.txt'), );

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

is_deeply( $A1->RawCount(), $expectA1,
  "Approval counted for a small set with no active list" );

my $A2 = $VC1->Approval(
  {
    'VANILLA'   => 1,
    'CHOCOLATE' => 1,
    'CARAMEL'   => 1,
    'PISTACHIO' => 0
  }
);
my $expectA2 = {
  CARAMEL   => 1,
  CHOCOLATE => 8,
  PISTACHIO => 2,
  VANILLA   => 10
};

is_deeply( $A2->RawCount(), $expectA2,
  "Approval counted a small set with AN active list" );

my $Range1 =
  Vote::Count->new(
  BallotSet => read_range_ballots('t/data/tennessee.range.json') );
my $R1A       = $Range1->Approval();
my $expectR1A = {
  CHATTANOOGA => 100,
  KNOXVILLE   => 100,
  MEMPHIS     => 100,
  NASHVILLE   => 100
};
is_deeply( $R1A->RawCount(), $expectR1A,
  'counted approval for a range ballotset' );

my $Range2 =
  Vote::Count->new(
  BallotSet => read_range_ballots('t/data/fastfood.range.json') );
my $R2A       = $Range2->Approval();
my $expectR2A = {
  "FIVEGUYS"   => 6,
  "MCDONALDS"  => 5,
  "WIMPY"      => 0,
  "WENDYS"     => 3,
  "QUICK"      => 3,
  "BURGERKING" => 11,
  "INNOUT"     => 10,
  "CARLS"      => 7,
  "KFC"        => 4,
  "TACOBELL"   => 4,
  "CHICKFILA"  => 6,
  "POPEYES"    => 4,
};
is_deeply( $R2A->RawCount(), $expectR2A,
  'counted approval for a second range ballotset' );

done_testing();
