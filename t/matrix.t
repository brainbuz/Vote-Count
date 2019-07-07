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
use Vote::Count::Matrix;
use Vote::Count::ReadBallots 'read_ballots';

my $M1 = Vote::Count::Matrix->new(
  'BallotSet' => read_ballots('t/data/ties1.txt'),
);

# can_ok( $M1,
#   [qw/Populate/],
#   "expected subs for a matrix");
isa_ok( $M1, ['Vote::Count::Matrix'],
'The matrix is a Vote::Count::Matrix');

subtest '_conduct_pair returns hash with pairing info' => sub {
  my $t1 = Vote::Count::Matrix::_conduct_pair(
    $M1->BallotSet, 'RUMRAISIN', 'STRAWBERRY');
  my $x1 = {
    loser    =>   "",
    margin   =>  0,
    RUMRAISIN  => 4,
    STRAWBERRY => 4,
    tie    => 1,
    winner=> "",
};
  is_deeply( $t1, $x1, 'A Tie');
  my $t2 = Vote::Count::Matrix::_conduct_pair(
    $M1->BallotSet, 'RUMRAISIN', 'FUDGESWIRL');
  my $x2 = {
    FUDGESWIRL => 6,
    loser => "RUMRAISIN",
    margin => 2,
    RUMRAISIN => 4,
    tie => 0,
    winner => "FUDGESWIRL",
};
  is_deeply( $t2, $x2, 'has winner');
};

subtest 'check some in the matrix' => sub {
  my $xVanMint = {
    loser    => "",
    margin   => 0,
    MINTCHIP => 6,
    tie      => 1,
    VANILLA  => 6,
    winner   => ""
  };
  my $xRockStraw = {
    loser      => "STRAWBERRY",
    margin     => 1,
    ROCKYROAD  => 5,
    STRAWBERRY => 4,
    tie        => 0,
    winner     => "ROCKYROAD"
  };
  my $VanMint = $M1->{'Matrix'}{'VANILLA'}{'MINTCHIP'};
  is_deeply( $xVanMint, $VanMint, 'check a tie');
  my $RockStraw = $M1->{'Matrix'}{'ROCKYROAD'}{'STRAWBERRY'};
  is_deeply( $xRockStraw, $RockStraw, 'one with a winner');
  is_deeply(
    $M1->{'Matrix'}{'FUDGESWIRL'}{'CHOCCHUNK'},
    $M1->{'Matrix'}{'CHOCCHUNK'}{'FUDGESWIRL'},
    'access a result in both possible pairing orders identical'
  );

};

done_testing();