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
use Vote::Count::RankCount;

# my $VC1 = Vote::Count->new( ballotset => read_ballots('t/data/data2.txt'), );

# my $tc1       = $VC1->TopCount();
my %set1 = (
  CARAMEL    => 0,
  CHOCOLATE  => 1,
  MINTCHIP   => 5,
  PISTACHIO  => 2,
  ROCKYROAD  => 0,
  RUMRAISIN  => 0,
  STRAWBERRY => 1,
  VANILLA    => 7 )
;

my $counted1 = Vote::Count::RankCount->Rank( \%set1 );
# p $counted1;
isa_ok( $counted1, ['Vote::Count::RankCount'],
  'Made a new counted object from rank' );

#   isa_ok($x, ['Vote::Count::TopCount::Rank'],
#     '->RankTopCount generated object of Vote::Count::TopCount::Rank');
  can_ok( $counted1, [qw/ RawCount HashWithOrder HashByRank ArrayTop ArrayBottom/],
    "have expected subs");

my %counted1raw = $counted1->RawCount();
is_deeply (
  \%set1,
  \%counted1raw,
  'the RawCount Method should return the same hash as was used to create the Rank object'
);

my %counted1ordered = $counted1->HashWithOrder();
is($counted1ordered{'VANILLA'}, 1 );

subtest 'HashByRank' => sub {
  my %counted1byrank = $counted1->HashByRank();
  is_deeply( $counted1byrank{3}, ['PISTACHIO'],
    'check an element from hashbyrank' );
  is_deeply(
    [ sort( $counted1byrank{4}->@* ) ],
    [ 'CHOCOLATE', 'STRAWBERRY' ],
    'check a different element that returns more than 1 value'
  );
};



# is_deeply( $tc1, $expecttc1,
#   "Topcounted a small set with no active list as expected" );


# my $tc2 = $VC1->TopCount(
#   {
#     'VANILLA'   => 1,
#     'CHOCOLATE' => 1,
#     'CARAMEL'   => 1,
#     'PISTACHIO' => 0
#   }
# );
# my $expecttc2 = {
#   CARAMEL   => 1,
#   CHOCOLATE => 1,
#   PISTACHIO => 2,
#   VANILLA   => 7
# };

# is_deeply( $tc2, $expecttc2,
#   "Topcounted a small set with AN active list as expected" );

# subtest 'TopCountMajority from the same data' => sub {
#   is_deeply( $VC1->TopCountMajority( ),
#     { thresshold => 8, votes => 15 },
#     'With full ballot TopCountMajority returns only votes and thresshold');
#   is_deeply( $VC1->TopCountMajority( $tc2 ),
#     { thresshold => 6, votes => 11, winner => 'VANILLA', winvotes => 7 },
#     'Topcount from saved subset topcount TopCountMajority also gives winner info');
# };

# subtest 'Topcount ranking' => sub {
#   #  my @rankedtc1 = ;
#   my $x = $VC1->RankTopCount();
#   isa_ok($x, ['Vote::Count::TopCount::Rank'],
#     '->RankTopCount generated object of Vote::Count::TopCount::Rank');
#   can_ok( $x, [qw/ hashwithorder hashbyrank arraytop arraybottom/],
#     "have expected subs");
#   my %xwithorder = $x->hashwithorder();
#   my %xbyrank = $x->hashbyrank();
#   my @xtop = $x->arraytop();
#   my @xbottom = $x->arraybottom();
#   p %xwithorder;
#   p %xbyrank;
#   p @xtop;
#   p @xbottom;
#   # is( , 'coffi');

#    };




done_testing();