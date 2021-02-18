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
use Vote::Count::Method::Cascade;
use Vote::Count::Charge::Utility 'FullCascadeCharge', 'NthApproval';
use Vote::Count::ReadBallots 'read_ballots';
use Test2::Tools::Exception qw/dies lives/;
use Test2::Tools::Warnings qw/warns warning warnings no_warnings/;
use Vote::Count::Charge::TestBalance 'balance_ok';
use Data::Printer;
# use Storable 3.15 'dclone';
use Data::Dumper;
# use Carp::Always;

my $DMB =
  Vote::Count::Method::Cascade->new(
    Seats     => 4,
    BallotSet => read_ballots('t/data/Scotland2017/Dumbarton.txt'),
    VoteValue => 100,
    LogTo     => '/tmp/votecount_cascademethod',
  );

ok 1;
$DMB->StartElection;
my $phase = 1;
my $looper = 1;
while ( $looper ) {
  $looper = $DMB->ConductQuotaRound( 'topcount');
  note( "Round: " . $DMB->Round() );
  }

# $DMB->ConductQuotaRound;
# say "===== " . $DMB->ConductQuotaRound;
# say "===== " . $DMB->ConductQuotaRound;
# $DMB->{DEBUG}=1;

# say "===== " . $DMB->ConductQuotaRound;
# while ($phase ) { $phase = $DMB->ConductQuotaRound() ;}
note( $DMB->logv );
note( Dumper $DMB->{'roundstatus'});
# p $DMB->meta()->{'methods'};

# subtest 'setup' => sub {
#   my $D = newD();
#   note( $D->TopCount()->RankTableWeighted(100) );
#   my @defeated = $D->DefeatLosers( 'precedence', NthApproval( $D ) );
#   note( "DEFEAT SURE LOSERS: @defeated ");

#   # note( $D->SureLoser );
#   $D->NewRound();
#   my $quota = $D->SetQuota();
#   my $abandoned = $D->CountAbandoned;
#   note( "quota $quota abandoned $abandoned->{value_abandoned} ");

#   $D->QuotaElectDo( $quota );
#   note( "Elected " . Dumper $D->Elected() );

#   $D->NewRound();
#   $quota = $D->SetQuota();
#   $abandoned = $D->CountAbandoned;
#   note( "quota $quota abandoned $abandoned->{value_abandoned} ");

#   $D->QuotaElectDo( $quota );
#   note( Dumper $D->TopCount()->RankTableWeighted( 1000) );
#   note( Dumper $D->Approval()->RankTableWeighted( 1000) );

#   # $A->Elect( 'William_GOLDIE_SNP');
#   # $A->Elect( 'Allan_GRAHAM_Lab');
#   ok $D;
# };

done_testing();

=pod

subtest 'calc charge bigger data' => sub {
  my $A = newA;
  $A->IterationLog( '/tmp/cascade_iteration');
  note( $A->TopCount()->RankTableWeighted( 100 ) );
  $A->NewRound();
  $A->Elect( 'William_GOLDIE_SNP');
  $A->Elect( 'Allan_GRAHAM_Lab');
  my $BCharge1 = $A->CalcCharge(120301);
  is_deeply( $BCharge1, #1203
    { Allan_GRAHAM_Lab => 83, William_GOLDIE_SNP => 67 },
    'Calculate the charge for the first 2 elected with the larger test set'
  );
  FullCascadeCharge( $A->GetBallots, 120301, $BCharge1, $A->GetActive, 100 );
  my $roundnum = $A->NewRound( 120301, $BCharge1 );
  my $TC = $A->TopCount();
$A->{'DEBUG'} = 1;
  my @newly = $A->QuotaElectDo( 120301 );
  my $lastcharge = $A->{'roundstatus'}{$roundnum -1 }{'charge'};
  my $BCharge2 = $A->CalcCharge(120301);
  is_deeply( $BCharge2, #1203
    { Allan_GRAHAM_Lab => 78, William_GOLDIE_SNP => 67, Stephanie_MUIR_Lab => 93 },
    'Calculate the charge adding the next quota winner'
  );
  my $Charge2F = FullCascadeCharge( $A->GetBallots, 120301, $BCharge2, $A->GetActive, 100 );
note Dumper  $Charge2F;
  my $balance = $A->VotesCast * 100;
  TestBalance ( $A->GetBallots, $Charge2F, $balance, $A->Elected() );
};


WIG
  name                      stage1  stage2  stage3  stage4  stage5
                                          round2
  BLACK, George (WDCP)       792  821.05  827.13  888.30    0.00
  CONAGHAN, Karen (SNP)     1499 1499.00 1313.00 1313.00 1313.00
  MCBRIDE, David (Lab)      1762 1313.00 1313.00 1313.00 1313.00
  MCLAREN, Iain (SNP)        809  827.09  989.76  998.64 1254.05
  MUIR, Andrew (Ind)         159  168.43  170.91    0.00    0.00
  RUINE, Elizabeth (Lab)     584  910.17  915.01  937.18 1103.63
  WALKER, Brian (Con)        957  979.68  980.55 1009.31 1147.13
  non-transferable             0   43.58   52.64  102.58  431.19

MEEK
  name                      stage1 stage2 stage3 stage4 stage5
                                          round2
  BLACK, George (WDCP)       792  827.1  887.0    0.0    0.0
  CONAGHAN, Karen (SNP)     1499 1302.1 1293.0 1235.7 1215.9
  MCBRIDE, David (Lab)      1762 1302.1 1293.0 1235.7 1215.8
  MCLAREN, Iain (SNP)        809 1001.6 1023.9 1343.6 1215.9
  MUIR, Andrew (Ind)         159  170.6    0.0    0.0    0.0
  RUINE, Elizabeth (Lab)     584  925.6  957.2 1217.3 1277.6
  WALKER, Brian (Con)        957  981.6 1010.7 1146.2 1154.0
  non-transferable             0   51.3   97.3  383.5  482.8