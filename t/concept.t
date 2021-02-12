#!/usr/bin/env perl

use 5.022;

# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
# use JSON::MaybeXS qw/encode_json/;
# use YAML::XS;
use feature qw /postderef signatures/;
no warnings 'experimental';
# use Path::Tiny;
use Vote::Count::Method::Concept;
use Vote::Count::ReadBallots 'read_ballots';
use Test2::Tools::Exception qw/dies lives/;
use Test2::Tools::Warnings qw/warns warning warnings no_warnings/;
use Storable 3.15 'dclone';
use Data::Dumper;

my $set1 = read_ballots('t/data/Scotland2012/Cumbernauld_South.txt');
my $data2 = read_ballots('t/data/data2.txt') ;

sub newA {
  Vote::Count::Method::Concept->new(
    Seats     => 4,
    BallotSet => dclone $set1,
    VoteValue => 100,
    LogTo     => '/tmp/votecount_wigm2',
  );
}

sub newB {
  Vote::Count::Method::Concept->new(
      Seats     => 2,
      BallotSet => dclone $data2,
      VoteValue => 100,
      LogTo     => '/tmp/votecount_wigm2',
    );
}

subtest 'quota' => sub {
  my $A = newA;
  my $B = newB;
  my $TC = $A->TopCount();
  # note( $TC->RankTable );
  # note( $A->VotesCast );
  is( $A->SetQuota(), 120301, 'Set initial Quota' );
  $A->Defeat( 'Stephanie_MUIR_Lab');
  $A->Elect( 'William_GOLDIE_SNP');
  $A->Charge ( 'William_GOLDIE_SNP', 120301, 70 );
  $A->Defeat( 'Paddy_HOGG_SNP');
  $A->Elect(  'Allan_GRAHAM_Lab');
  $A->Charge ( 'Allan_GRAHAM_Lab', 120301, 90 );
  $TC = $A->TopCount();
  # note( $TC->RankTable );
  # note( Dumper $A->CountAbandoned);
  # This quota was never hand checked.
  is( $A->SetQuota(), 103957, 'Set a new Quota after some elections and defeats' );
  $TC = $B->TopCount( );
  # note( $TC->RankTable() );
  $B->Defeat('VANILLA');
  $B->Elect('MINTCHIP');
  $B->Charge( 'MINTCHIP', 300, 60);
  $TC = $B->TopCount( );
  # note( $TC->RankTable() );
  # note( Dumper $B->LastTopCountUnWeighted() );
  is( $B->SetQuota(), 381, 'Small data set hand validated calculation after elections and defeats' );
};

subtest 'newround and _preEstimate' => sub {
  my $B =newB;
  my $TC = $B->TopCount();
  my $quota = 375; # correct value is 376, this is for easier hand checking.
  # note( Dumper $B->CalcCharge( $quota, $TC, 'VANILLA', 'MINTCHIP' ) );
  my ( $est, $cap ) = Vote::Count::Method::Concept::_preEstimate( $B, $quota, 'VANILLA', 'MINTCHIP' );
  is_deeply(
    $est,
    { 'MINTCHIP' => 75, 'VANILLA' => 53 },
    'Check first estimate');
  is_deeply(
    $cap,
    { 'MINTCHIP' => 100, 'VANILLA' => 100 },
    'Check cap on first estimate');
  $B->{'roundstatus'}{97}{'charge'}{'VANILLA'} = 59;
  $B->{'currentround'} = 98;
  ( $est, $cap ) = Vote::Count::Method::Concept::_preEstimate( $B, $quota, 'VANILLA', 'MINTCHIP' );
  is_deeply(
    $est,
    { 'MINTCHIP' => 75, 'VANILLA' => 59 },
    'Check estimate where there was a prior charge');
  is_deeply(
    $cap,
    { 'MINTCHIP' => 100, 'VANILLA' => 59 },
    'Check estimate where there was a prior charge');
  $B->{'currentround'} = 0;
  delete $B->{'roundstatus'}{97};
  is( $B->NewRound(), 1, 'NewRound returns new round number');
  is( $B->NewRound(), 2, 'NewRound returns next round number');
  is( $B->Round(), 2, 'double check the currentround with round method');
};

subtest '_chargeInsight' => sub {
  my $A = newA;
  my $B = newB;
  # $B->TopCount;
  $B->Elect( 'VANILLA');
  $B->Elect( 'MINTCHIP');
  my $estimate = { 'MINTCHIP' => 83, 'VANILLA' => 44 };
  my $cap = { 'MINTCHIP' => 100, 'VANILLA' => 100 };
  my $freeze = {};
  my $C1 = $B->_chargeInsight( 375, $estimate, $cap, $freeze, 'MINTCHIP', 'VANILLA' );
  is_deeply( $C1->{result}{VANILLA},
    { 'count' => 7, 'surplus' => -67, 'charge' => 44, 'value' => 308 },
    'look at the result for a choice' );
  is_deeply( $C1->{est},
    { 'MINTCHIP' => 75, 'VANILLA' => 54 },
    'check the estimate no caps or freezes in play' );
  $cap = { 'MINTCHIP' => 100, 'VANILLA' => 50 };
  my $C2 = $B->_chargeInsight( 375, $estimate, $cap, $freeze, 'MINTCHIP', 'VANILLA' );
  is_deeply( $C2->{est},
    { 'MINTCHIP' => 75, 'VANILLA' => 50 },
    'check the estimate with a cap in play' );
  $cap = { 'MINTCHIP' => 100, 'VANILLA' => 100 };
  $freeze = { 'VANILLA' => 66 };
  my $C3 = $B->_chargeInsight( 375, $estimate, $cap, $freeze, 'MINTCHIP', 'VANILLA' );
  # note( Dumper $C3);
  is_deeply( $C3->{est},
    { 'MINTCHIP' => 75, 'VANILLA' => 66 },
    'check the estimate with a freeze in play' );

  ok 1;

};


subtest 'calc charge' => sub {
  my $A = newA;
  my $B = newB;
  $B->TopCount;
  $B->Elect( 'VANILLA');
  $B->Elect( 'MINTCHIP');
  # note( Dumper $B->CalcCharge( 375 ));

  ok 1;

};

done_testing();

=pod
$D->WIGRun();
is_deeply(  [ $D->Elected()],
            [ qw/William_GOLDIE_SNP Allan_GRAHAM_Lab Stephanie_MUIR_Lab Paddy_HOGG_SNP/],
            'choices elected in correct order' );

$D->WriteLog();
$D->WriteSTVEvent();
my @evt = $D->STVEvent()->@*;
is_deeply( $evt[-1], {
  'winners' => [
    'William_GOLDIE_SNP', 'Allan_GRAHAM_Lab',
    'Stephanie_MUIR_Lab', 'Paddy_HOGG_SNP'
  ] },
  'last item in STVEvent is the winners record' );
my $expectround2 = {
            'lowest'   => 'Kevin_MCVEY_SSP',
            'allvotes' => {
              'Donald_MASTERTON_CICA' => 36312966,
              'Kevin_MCVEY_SSP'       => 15234225,
              'Willie_HOMER_SNP'      => 79245144,
              'Paddy_HOGG_SNP'        => 81581751,
              'David_MCARTHUR_Con'    => 23213254,
              'Stephanie_MUIR_Lab'    => 121042787
            },
            'quota'    => 120400000,
            'noncontinuing' => 4068615,
            'winvotes' => {
              'Stephanie_MUIR_Lab' => 121042787
            },
            'pending' => ['Stephanie_MUIR_Lab'],
            'round'   => 2
          };
    is_deeply( $evt[2] , $expectround2, 'STVEvent check round 2' );

done_testing();

=pod

"name"                      stage1  stage2  stage3  stage4  stage5  stage6  stage7
"rounds"                    round1  ------  round2  round3  round4  round5  round6
  "GOLDIE, William (SNP)"     1779 1204.00 1204.00 1204.00 1204.00 1204.00 1204.00
  "GRAHAM, Allan (Lab)"       1413 1413.00 1204.00 1204.00 1204.00 1204.00 1204.00
  "HOGG, Paddy (SNP)"          444  810.20  815.82  816.32  836.42  857.55  926.39
  "HOMER, Willie (SNP)"        653  783.58  792.45  792.87  819.18  832.46  916.95
  "MASTERTON, Donald (CICA)"   344  358.54  363.13  363.68  392.87  486.34    0.00
  "MCARTHUR, David (Con)"      225  228.88  232.13  232.41  235.75    0.00    0.00
  "MCVEY, Kevin (SSP)"         140  147.76  152.34  153.14    0.00    0.00    0.00
  "MUIR, Stephanie (Lab)"     1017 1044.47 1210.43 1204.00 1204.00 1204.00 1204.00
  "non-transferable"             0   24.57   40.70   44.58  118.77  226.65  559.67
