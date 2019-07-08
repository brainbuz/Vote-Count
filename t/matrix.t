#!/usr/bin/env perl

use 5.026;

# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Data::Printer;
use JSON::MaybeXS;
use YAML::XS;
use feature qw /postderef signatures/;

my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1 );

use Path::Tiny;

use Vote::Count;
use Vote::Count::Matrix;
use Vote::Count::ReadBallots 'read_ballots';

my $M1 = Vote::Count::Matrix->new(
  'BallotSet' => read_ballots('t/data/ties1.txt'),
);

my $M2 = Vote::Count::Matrix->new(
  'BallotSet' => read_ballots('t/data/data1.txt'),
);

my $M3 = Vote::Count::Matrix->new(
  'BallotSet' => read_ballots('t/data/data2.txt'),
);

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

subtest '_scorematrix' => sub {
  my $scored1 = $M2->_scorematrix();
  my $xscored1 = {
    CARAMEL   =>   1,
    CHOCOLATE  =>  5,
    MINTCHIP     => 7,
    PISTACHIO  =>  1,
    ROCKYROAD  =>  0,
    RUMRAISIN  =>  0,
    STRAWBERRY =>  0,
    VANILLA    =>  6
};
  is_deeply( $scored1, $xscored1, 'check scoring for a dataset');
  my $xscored2 = {
    CHOCOLATE  =>  1,
    MINTCHIP     => 3,
    PISTACHIO  =>  0,
    VANILLA    =>  2
};

  $M2->Active( $xscored2 );
  my $scored2 = $M2->_scorematrix();
  is_deeply( $scored2, $xscored2,
    'check scoring same data after eliminating some choices');
};

subtest 'CondorcetLoser elimination' => sub {
  my $E2 =  $M2->CondorcetLoser();
  is ( $E2->{'terse'},
    "Eliminated Condorcet Losers: PISTACHIO, CHOCOLATE, VANILLA\n",
    "terse is list of eliminated losers");

like(
  $E2->{'verbose'},
  qr/^Removing Condorcet Losers/,
  'check verbose for expected first line');
like(
  $E2->{'verbose'},
  qr/Eliminationg Condorcet Loser: \*CHOCOLATE\*/,
  'check verbose for an elimination notice');
is_deeply ( $M2->{'Active'}, { 'MINTCHIP' => 3},
  'only the condorcet winner remains in active') ;

};

subtest '_getsmithguessforchoice' => sub {
  my %rumr = Vote::Count::Matrix::_getsmithguessforchoice(
    'RUMRAISIN', $M1->{'Matrix'});
  is( scalar(keys %rumr), 11,
    'choice with a lot of losses proposed large smith set');
  my %mchip = Vote::Count::Matrix::_getsmithguessforchoice(
    'MINTCHIP', $M1->{'Matrix'});
  is_deeply([ sort keys %mchip ], [ qw/ BUBBLEGUM MINTCHIP VANILLA/],
      'choice with 1 defeat and 1 tie returned correct 3 choices');
};

done_testing();