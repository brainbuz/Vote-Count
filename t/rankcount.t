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

my $counted1raw = $counted1->RawCount();
is_deeply (
  \%set1,
  $counted1raw,
  'the RawCount Method should return the same hash as was used to create the Rank object'
);

my $counted1ordered = $counted1->HashWithOrder();
is($counted1ordered->{'VANILLA'}, 1 );

subtest 'HashByRank' => sub {
  my $counted1byrank = $counted1->HashByRank();
  is_deeply( $counted1byrank->{3}, ['PISTACHIO'],
    'check an element from hashbyrank' );
  is_deeply(
    [ sort( $counted1byrank->{4}->@* ) ],
    [ 'CHOCOLATE', 'STRAWBERRY' ],
    'check a different element that returns more than 1 value'
  );
};

# always sort so we don't care if deeply cares about order.
# p $counted1;
my $counted1top = $counted1->ArrayTop();

my $counted1bottom = $counted1->ArrayBottom();

is_deeply( $counted1top, [ 'VANILLA' ], "confirm top element");
is_deeply( $counted1bottom, [ qw( CARAMEL ROCKYROAD RUMRAISIN ) ],
 "confirm bottom elements");

# p $counted1;
my $table = $counted1->RankTable();
my $xtable = q/| Rank | Choice     | Votes |
|------|------------|-------|
| 1    | VANILLA    | 7     |
| 2    | MINTCHIP   | 5     |
| 3    | PISTACHIO  | 2     |
| 4    | CHOCOLATE  | 1     |
| 4    | STRAWBERRY | 1     |
| 5    | CARAMEL    | 0     |
| 5    | ROCKYROAD  | 0     |
| 5    | RUMRAISIN  | 0     |/;
is( $table, $xtable, 'Generate a table with ->RankTable()');

done_testing();