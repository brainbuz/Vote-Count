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
use Vote::Count::VoteCharge::Utility 'FullCascadeCharge';
use Vote::Count::ReadBallots 'read_ballots';
use Test2::Tools::Exception qw/dies lives/;
use Test2::Tools::Warnings qw/warns warning warnings no_warnings/;
use Storable 3.15 'dclone';
use Data::Dumper;

subtest 'FullCascadeCharge' => sub {
  my $H = read_ballots 't/data/data2.txt' ;
  my $cost = { 'MINTCHIP' => 75, 'VANILLA' => 54 };
  my $active = { 'CHOCOLATE' => 1, 'STRAWBERRY' => 1, 'PISTACHIO' => 1, 'ROCKYROAD' => 1, 'CARAMEL' => 1, 'RUMRAISIN' => 1};
  my $crg1 = FullCascadeCharge(
            $H->{'ballots'}, 375, $cost, $active, 100);
  my $chk1 = {
      'VANILLA' => {
        'count' => 7,
        'value' => 378,
        'surplus' => 3
      },
      'MINTCHIP' => {
          'surplus' => 0,
          'value' => 375,
          'count' => 5
        }
      };
  is_deeply( $crg1, $chk1, 'two quota choices first round charge ok' );
  delete $active->{'CHOCOLATE'};

  $cost = { 'MINTCHIP' => 75, 'VANILLA' => 54, 'CHOCOLATE' => 100 };

  my $crg2 = FullCascadeCharge(
            $H->{'ballots'}, 375, $cost, $active, 100);
  note( Dumper $crg1 );
  my $chk2 = {
      'VANILLA' => {
        'count' => 7,
        'value' => 378,
        'surplus' => 3
      },
      'MINTCHIP' => {
          'surplus' => 0,
          'value' => 375,
          'count' => 5
        },
      'CHOCOLATE' => {
          'surplus' => -45,
          'value' => 330,
          'count' => 6
        }
      };
  is_deeply( $crg2, $chk2, 'same with additional choice under quota' );
  my $valelect = 0;
  for ( 'VANILLA', 'MINTCHIP', 'CHOCOLATE' ) {
      $valelect += $crg2->{$_}{'value'} };
  my $valremain = 0 ;
  for my $k ( keys $H->{'ballots'}->%* ) {
    $valremain +=
      $H->{'ballots'}{$k}{'votevalue'} * $H->{'ballots'}{$k}{'count'};
  }
  is( $valremain + $valelect, 1500,
    'sum of elected value plus remaining value matches total vote value');
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
