#!/usr/bin/env perl

use 5.022;

# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Data::Printer;
# use JSON::MaybeXS;
# use YAML::XS;
use feature qw /postderef signatures/;

# my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1 );

use Path::Tiny;

use Vote::Count::Method::CondorcetDropping;
use Vote::Count::ReadBallots 'read_ballots';

subtest 'Plurality Loser Dropping (TopCount)' => sub {

my $M3 =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/biggerset1.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'topcount',
  );
isa_ok( $M3, ['Vote::Count::Method::CondorcetDropping'],
  'ISA Vote::Count::Method::CondorcetDropping' );
my $rM3 = $M3->RunCondorcetDropping();
is ( $rM3, 'MINTCHIP', 'winner for biggerset1 topcount/all');
# note $M3->logv();

my $LoopSet =
  Vote::Count::Method::CondorcetDropping->new( 'BallotSet' => read_ballots('t/data/loop1.txt'),
  );
my $rLoopSet = $LoopSet->RunCondorcetDropping();
is( $rLoopSet, 'MINTCHIP', 'loopset plurality leastwins winner');
# note $LoopSet->logd();

my $LoopSetA =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/loop1.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'topcount',
  );
my $rLoopSetA = $LoopSetA->RunCondorcetDropping();
is( $rLoopSetA, 'MINTCHIP', 'loopset plurality leastwins winner is the same');
# note $LoopSetA->logd();

my $KnotSet =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/knot1.txt'),
  );

my $rKnotSet = $KnotSet->RunCondorcetDropping();
is( $rKnotSet, 'CHOCOLATE', 'knotset winner with defaults');
# note $KnotSet->logd();
};

note "==== Edgeleastwins";
my $edge =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/condorcetdropping_edgecase.txt'),
  );
my $redge = $edge->RunCondorcetDropping();
# is( $redge, 'CHOCOLATE', 'knotset winner with defaults');
note $edge->logd();

note "==== Edgeall";
my $edge1 =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/condorcetdropping_edgecase.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'topcount',
  );
my $redge1 = $edge1->RunCondorcetDropping();
# is( $redge, 'CHOCOLATE', 'knotset winner with defaults');
note $edge1->logd();


subtest 'Approval Dropping' => sub {

note "********** LOOPSET *********";
my $LoopSet =
  Vote::Count::Method::CondorcetDropping->new(
  'BallotSet' => read_ballots('t/data/loop1.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'approval',
  );
my $rLoopSet = $LoopSet->RunCondorcetDropping();
is( $rLoopSet, 'VANILLA', 'loopset approval all winner');
note $LoopSet->logd();
};

subtest 'Boorda Dropping' => sub {

note "\n********** LOOPSET BOORDA *********";
my $LoopSetB =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/loop1.txt'),
    'DropStyle' => 'leastwins',
    'DropRule'  => 'boorda',
  );
my $rLoopSetB = $LoopSetB->RunCondorcetDropping();
is( $rLoopSetB, 'MINTCHIP', 'loopset plurality leastwins winner is the same');
note $LoopSetB->logd();

note "\n********** KNOTSET BOORDA *********";
my $KnotSet =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => read_ballots('t/data/knot1.txt'),
    'DropStyle' => 'all',
    'DropRule'  => 'boorda',
  );

my $rKnotSet = $KnotSet->RunCondorcetDropping();
is( $rKnotSet, 'MINTCHIP', 'knotset winner with defaults');
note $KnotSet->logd();
};



done_testing();