#!/usr/bin/env perl

use 5.024;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test2::Tools::Exception qw/dies lives/;
use Test2::Tools::Warnings qw/warns warning warnings no_warnings/;

# use Test::Exception;
# use Data::Dumper;

use Path::Tiny;
use Try::Tiny;
use Storable 'dclone';

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots', 'read_range_ballots';
# use Vote::Count::Helper::BottomRunOff;

use feature qw /postderef signatures/;
no warnings 'experimental';

use Data::Printer;
use Carp::Always;

my $B1 =  Vote::Count->new(
  BallotSet => read_ballots('t/data/biggerset1.txt'),
    TieBreakerFallBackPrecedence => 0 );

my $B2 = Vote::Count->new(
  BallotSet => read_ballots( 't/data/biggerset1.txt'),
  PrecedenceFile => 't/data/biggerset1precedence.txt',
  TieBreakMethod => 'grandjunction',
  Debug => 1,
  TieBreakerFallBackPrecedence => 1 );

my $Tweedles = Vote::Count->new(
  BallotSet => read_ballots('t/data/tweedles.txt'),
  TieBreakMethod => 'Precedence',
  # TieBreakerFallBackPrecedence => 1 ,
  PrecedenceFile => 't/data/tweedlesprecedence2.txt' );

like(
  dies { $B1->BottomRunOff() },
  qr/TieBreakerFallBackPrecedence must be enabled/,
  "BottomRunOff dies if Precedence isnt available."
);

my $etable = qq/Elimination Runoff: *RUMRAISIN* 36 > ROCKYROAD 21/;
is_deeply(  $B2->BottomRunOff(), # defaults
 { eliminate => 'ROCKYROAD', continuing => 'RUMRAISIN', runoff => $etable },
 'BottomRunOff picked the winner and eliminate and had the right message'
 );

$B2->Defeat( 'CHOCOANTS');
$B2->Defeat( 'TOAD');
$B2->Defeat( 'CHSOGGYCHIPSOCOANTS');
my $R = $B2->BottomRunOff();
is_deeply(  $R,
 { eliminate => 'ROCKYROAD', continuing => 'RUMRAISIN', runoff => $etable },
 'Eliminated some other weak choices still had the same bottom runoff'
 );
$B2->Defeat( 'ROCKYROAD');

my @t = $B2->UnTieActive( ranking1 => 'topcount', ranking2 => 'precedence');
note "@t";
note $B2->TopCount->RankTable;
note $B2->Approval->RankTable;

$R = $B2->BottomRunOff();
is( $R->{eliminate}, 'RUMRAISIN', 'Eliminated last defeated choice check elimination');
is( $R->{continuing}, 'STRAWBERRY', ' - then check continuing');

$R = $B2->BottomRunOff( ranking2 => 'Approval');
is( $R->{continuing}, 'CARAMEL', 'Approval as ranking2 had different pair');
is( $R->{eliminate}, 'RUMRAISIN', 'Approval as ranking2 had different pair check other member');

$B2->Defeat( 'STRAWBERRY');
$B2->Defeat( 'RUMRAISIN');
$R = $B2->BottomRunOff();
is( $R->{eliminate}, 'SOGGYCHIPS', 'Eliminated the lowest choices check elimination');
is( $R->{continuing}, 'CARAMEL', ' - then check continuing');

$B2->Defeat( 'SOGGYCHIPS');
$B2->Defeat( 'VOMIT');
$R = $B2->BottomRunOff();
is( $R->{eliminate}, 'PISTACHIO', 'Eliminated more low choices check elimination');
is( $R->{continuing}, 'CARAMEL', ' - then check continuing');
$B2->Defeat( 'PISTACHIO');
$R = $B2->BottomRunOff();
is( $R->{eliminate}, 'CARAMEL', 'Eliminated next low choice');
is( $R->{continuing}, 'CHOCOLATE', ' - then check continuing');
$B2->Defeat( 'CARAMEL');
$R = $B2->BottomRunOff();
$etable = "Elimination Runoff: *MINTCHIP* 88 > CHOCOLATE 87";
is_deeply(  $R,
 { eliminate => 'CHOCOLATE', continuing => 'MINTCHIP', runoff => $etable },
 'Now getting down to the more popular choices, checking all values again' );

# Add some tests for ties in the matrix resolved by precedence.
$R = $Tweedles->BottomRunOff();
$etable = q/Elimination Runoff: *TWEEDLE_THREE* 50 > TWEEDLE_DO 50/;
is_deeply(  $R,
 { continuing => 'TWEEDLE_THREE', eliminate => 'TWEEDLE_DO', runoff => $etable },
 'check a tie that can only resolve by precedence, which is done through matrix'
 );

subtest 'synopsis' => sub {
  my $Election = $Tweedles;
# begin synopsis
  my $eliminate = $Election->BottomRunOff();
  # log the pairing result
  $Election->logd( $eliminate->{'runoff'} );
  # log elimination in the short log too.
  $Election->logt( "eliminated ${\ $eliminate->{'eliminate'} }.");
  # Perform the elimination
  $Election->Defeat( $eliminate->{'eliminate'} );
# end synopsis
  pass( 'No exceptions in synopsis block');
  like( $Election->logt,
    qr/eliminated TWEEDLE_DO./,
    'Check terse log for elimination'
  );
};


done_testing;