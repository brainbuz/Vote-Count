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
use Vote::Count::Boorda;


my $VC1 = Vote::Count->new(
  ballotset => read_ballots('t/data/data1.txt'), );

subtest '_boordashrinkballot private method' => sub {
my $shrunken = Vote::Count::Boorda::_boordashrinkballot (
  $VC1->ballotset(),
  { 'CARAMEL' => 1, 'STRAWBERRY' => 1, 'MINTCHIP' => 1 }
  );
# p $shrunken;

is( $shrunken->{
  'CHOCOLATE:MINTCHIP:VANILLA'}{'votes'}[0],
  'MINTCHIP',
  'Check the remaining member of a reduced ballot'
);

is( $shrunken->{
  'MINTCHIP'}{'count'},
  4,
  'Check that a choice with multiple votes stil has them'
);
is( scalar( $shrunken->{
   'MINTCHIP:CARAMEL:RUMRAISIN'}{'votes'}->@*),
  2,
  'choice that still has multipe choices has the right number'
);
};

subtest '_doboordacount private method' => sub {
  my $bordatable = {
    'VANILLA' => { 1 => 4, 2 => 6, 3 => 9 },
    'RAISIN' => { 1 => 6, 3 => 2 },
    'CHERRY' => { 2 => 5 }
  };
  my $lightweight = sub { return 1 };
  my $counted = Vote::Count::Boorda::_doboordacount(
    $bordatable, $lightweight );
  is( $counted->{'VANILLA'}, 19,
    'check count for first choice' );
  is( $counted->{'RAISIN'}, 8,
    'check count for second choice' );
  is( $counted->{'CHERRY'}, 5,
    'check count for third choice' );
};

my ( $A1Rank, $A1Boorda ) = $VC1->Boorda();
# p $A1Rank;
# p $A1Boorda;


my $expectA1 = {
  CARAMEL    => 4,
  CHOCOLATE  => 10,
  MINTCHIP   => 32,
  PISTACHIO  => 5,
  ROCKYROAD  => 4,
  RUMRAISIN  => 3,
  STRAWBERRY => 3,
  VANILLA    => 20,
};

# p $A1Rank->RawCount();
is_deeply( $A1Rank->RawCount(), $expectA1,
  "Boorda counted for a small set with no active list" );

my $testweight = sub {
  my $x = shift;
  if    ( $x == 1 ) { return 12 }
  elsif ( $x == 2 ) { return 6 }
  elsif ( $x == 3 ) { return 4 }
  elsif ( $x == 4 ) { return 3 }
  else              { return 0 }
};

my $VC2 = Vote::Count->new(
  ballotset   => read_ballots('t/data/data2.txt'),
  bordaweight => $testweight,
);

my ($A2, $B2 )     = $VC2->Boorda(
    { 'VANILLA' => 1, 'CHOCOLATE' => 1, 'CARAMEL' => 1,
      'PISTACHIO' => 0 });
my $expectA2 = {
  CARAMEL    => 12,
  CHOCOLATE  => 50,
  PISTACHIO  => 24,
  VANILLA    => 102
};

is_deeply( $A2->RawCount(), $expectA2,
  "Approval counted a small set with AN active list" );

is_deeply(
  $B2->{'CHOCOLATE'},
  { 1 => 1, 2 => 5, 3 => 2 },
  'test a value on the Boorda Ranking table.'
);
done_testing();