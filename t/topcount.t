#!/usr/bin/env perl

use 5.026;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Data::Printer;

use Path::Tiny;

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

my $VC1 = Vote::Count->new( ballotset => read_ballots('t/data/data2.txt'), );

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


my $tc2 = $VC1->TopCount(
  {
    'VANILLA'   => 1,
    'CHOCOLATE' => 1,
    'CARAMEL'   => 1,
    'PISTACHIO' => 0
  }
);
my $expecttc2 = {
  CARAMEL   => 1,
  CHOCOLATE => 1,
  PISTACHIO => 2,
  VANILLA   => 7
};

is_deeply( $tc2, $expecttc2,
  "Topcounted a small set with AN active list as expected" );

subtest 'TopCountMajority from the same data' => sub {
  is_deeply( $VC1->TopCountMajority( ),
    { thresshold => 8, votes => 15 },
    'With full ballot TopCountMajority returns only votes and thresshold');
  is_deeply( $VC1->TopCountMajority( $tc2 ),
    { thresshold => 6, votes => 11, winner => 'VANILLA', winvotes => 7 },
    'Topcount from saved subset topcount TopCountMajority also gives winner info');
};

subtest 'Topcount ranking' => sub {
  #  my @rankedtc1 = ;
  my $x = $VC1->RankTopCount();
  isa_ok($x, ['Vote::Count::TopCount::Rank'],
    '->RankTopCount generated object of Vote::Count::TopCount::Rank');
  can_ok( $x, [qw/ hashwithorder hashbyrank arraytop arraybottom/],
    "have expected subs");
  my %xwithorder = $x->hashwithorder();
  my %xbyrank = $x->hashbyrank();
  my @xtop = $x->arraytop();
  my @xbottom = $x->arraybottom();
  p %xwithorder;
  p %xbyrank;
  p @xtop;
  p @xbottom;
  # is( , 'coffi');

   };




done_testing();