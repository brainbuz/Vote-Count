#!/usr/bin/env perl

use 5.022;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use File::Temp qw/tempfile tempdir/;
# use Test::Exception;
use Data::Dumper;

use Path::Tiny;
# use Storable 'dclone';

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

use feature qw /postderef signatures/;
no warnings 'experimental';

my $ties = Vote::Count->new( BallotSet => read_ballots('t/data/ties1.txt'), );
# my $knot = Vote::Count->new(
#   BallotSet => read_ballots('t/data/knot1.txt'), );
my $irvtie =
  Vote::Count->new( BallotSet => read_ballots('t/data/irvtie.txt'), );
# my $brexit = Vote::Count->new(
#   BallotSet => read_ballots('t/data/brexit1.txt'), );
my $set4 =
  Vote::Count->new( BallotSet => read_ballots('t/data/majority1.txt') );

subtest 'Modified GrandJunction TieBreaker' => sub {

  my @all4ties =
    qw(VANILLA CHOCOLATE STRAWBERRY FUDGESWIRL PISTACHIO ROCKYROAD MINTCHIP CARAMEL RUMRAISIN BUBBLEGUM CHERRY CHOCCHUNK);
  my $allintie = $ties->TieBreakerGrandJunction(@all4ties);
  is( $allintie->{'winner'}, 0, 'tiebreaker with no winner returned 0' );
  is( $allintie->{'tie'},    1, 'tiebreaker with no winner tie is true' );
  is_deeply(
    $allintie->{'tied'},
    [ 'FUDGESWIRL', 'VANILLA' ],
'tiebreaker (multi tie) with no winner tied contains remaining tied choices'
  );

  is( $irvtie->TieBreakerGrandJunction(qw/ VANILLA CHOCOLATE /)->{'winner'},
    'VANILLA', 'check winner of a tie break vanilla' );
  my $textrsltB = $irvtie->logd();
  like( $textrsltB, qr/CHOCOLATE: 31/, 'from log chocolate had 31 votes.' );
  like( $textrsltB, qr/VANILLA: 40/,   'from log vanilla had 40 votes.' );
  is( $irvtie->TieBreakerGrandJunction(qw/  CARAMEL RUMRAISIN /)->{'winner'},
    'RUMRAISIN', 'RUMRAISIN check winner of a tie break ' );
  is(
    $irvtie->TieBreakerGrandJunction(qw/  STRAWBERRY PISTACHIO ROCKYROAD /)
      ->{'winner'},
    'PISTACHIO', 'PISTACHIO check winner of a tie break'
  );

  my $s4 = $set4->TieBreakerGrandJunction( 'SUZIEQ', 'YODEL' );
  is( $s4->{'winner'}, 'SUZIEQ', 'a tiebreaker that went down 3 levels' );
};

subtest 'object tiebreakers' => sub {
  my $active = {
    PISTACHIO => 1,
    ROCKYROAD => 1,
    CHOCOLATE => 1,
    VANILLA   => 1,
  };
  my $I5 = Vote::Count->new( BallotSet => read_ballots('t/data/irvtie.txt') );
  my @resolve1 =
    sort $I5->TieBreaker( 'none', $active, ( 'VANILLA', 'CHOCOLATE' ) );
  is_deeply(
    \@resolve1,
    [ 'CHOCOLATE', 'VANILLA' ],
    'none returns both tied choices'
  );
  my @resolve2 =
    sort $I5->TieBreaker( 'borda', $active, ( 'VANILLA', 'CHOCOLATE' ) );
  is_deeply( \@resolve2, ['CHOCOLATE'], 'Borda returns choice that won' );
  my @resolve3 =
    sort $I5->TieBreaker( 'borda_all', $active, ( 'VANILLA', 'CHOCOLATE' ) );
  is_deeply( \@resolve3, ['VANILLA'],
'borda_all returns choice that won (different winner than borda on active!)'
  );
  my @resolve4 =
    sort $I5->TieBreaker( 'approval', $active, ( 'VANILLA', 'CHOCOLATE' ) );
  is_deeply(
    \@resolve4,
    [ 'CHOCOLATE', 'VANILLA' ],
    'approval returns a tie for the top2'
  );
  my @resolve5 =
    sort $I5->TieBreaker( 'approval', $active, ( 'VANILLA', 'ROCKYROAD' ) );
  is_deeply( \@resolve5, ['VANILLA'], 'approval winner for a non-tied pair' );

  my @resolve6 = sort $I5->TieBreaker( 'grandjunction', $active,
    ( 'VANILLA', 'ROCKYROAD' ) );
  is_deeply( \@resolve6, ['VANILLA'], 'modified grand junction' );

  my @resolve7 =
    $I5->TieBreaker( 'all', $active, ( 'VANILLA', 'ROCKYROAD' ) );

  note( Dumper @resolve7 );

  is( @resolve7, 0, 'all returns an empty array.' );
};

subtest 'Precedence' => sub {
  $ties->TieBreakMethod('precedence');
  $ties->PrecedenceFile('t/data/tiebreakerprecedence1.txt');

  my @all4ties =
    qw(VANILLA CHOCOLATE STRAWBERRY PISTACHIO FUDGESWIRL ROCKYROAD MINTCHIP CARAMEL RUMRAISIN BUBBLEGUM CHERRY CHOCCHUNK);

  my $allintie = $ties->TieBreakerPrecedence(@all4ties);
  is( $allintie->{'winner'}, 'FUDGESWIRL',
    'all choices in tie chose #1 precedence choice' );
  my @mostinties =
    qw(VANILLA CHOCOLATE STRAWBERRY MINTCHIP CARAMEL RUMRAISIN BUBBLEGUM CHERRY CHOCCHUNK);
  my @mosttied =
    $ties->TieBreaker( $ties->TieBreakMethod(), $ties->Active(),
    @mostinties );
  is_deeply( \@mosttied, ['MINTCHIP'],
    'shorter choices without precedence leaders returned right choice' );

  #   diag( 'switching precedence file');
  $ties->PrecedenceFile('t/data/tiebreakerprecedence2.txt');
  my @tryagain = $ties->TieBreaker( $ties->TieBreakMethod(),
    $ties->Active(), qw( BUBBLEGUM CARAMEL) );
  is_deeply( \@tryagain, ['CARAMEL'],
    'shorter choices without precedence leaders returned right choice' );
  dies_ok(
    sub {
      $ties->TieBreaker( $ties->TieBreakMethod(),
        $ties->Active(), qw( FUDGESWIRL CARAMEL) );
    },
    "choice missing in precedence file is fatal"
  );
};

subtest 'utility method to generate a Predictable Random Precedence File.' =>
  sub {
  unlink('/tmp/precedence.txt');
  my @prec1 = $set4->CreatePrecedenceRandom();
  my $expectprec1 =
    [qw/ YODEL RINGDING DEVILDOG KRIMPET HOHO TWINKIE SUZIEQ/];
  is_deeply( \@prec1, $expectprec1,
    'Predictable Randomized order for ballotfile majority1.txt' );
  my @readback = path('/tmp/precedence.txt')->lines();
  chomp(@readback);
  is_deeply( \@readback, $expectprec1,
    'readback of precedence written to default /tmp/precedence.txt' );

  my ( $dst, $tmp2 ) = tempfile();
  close $dst;
  my @prec2 = Vote::Count->new( BallotSet => $ties->BallotSet )
    ->CreatePrecedenceRandom($tmp2);
  my $expectprec2 = [
    qw/BUBBLEGUM CHOCOLATE PISTACHIO CARAMEL VANILLA STRAWBERRY
      MINTCHIP RUMRAISIN FUDGESWIRL CHERRY CHOCCHUNK ROCKYROAD/
  ];
  is_deeply( \@prec2, $expectprec2,
    'Predictable Randomized order for ballotfile ties1.txt' );
  @readback = path($tmp2)->lines();
  chomp(@readback);
  is_deeply( \@readback, $expectprec2,
    "readback of precedence written to generated $tmp2" );
  };

subtest 'TieBreakerFallBackPrecedence' => sub {
  my $ties = Vote::Count->new(
    BallotSet                    => read_ballots('t/data/ties1.txt'),
    TieBreakerFallBackPrecedence => 1,
  );
  ok( $ties->TieBreakerFallBackPrecedence(), 'fallback precedence is set' );
  is( $ties->PrecedenceFile(),
    '/tmp/precedence.txt', 'precedence file set when not provided' );
  my @thetie   = qw(PISTACHIO RUMRAISIN BUBBLEGUM);
  my $allintie = $ties->TieBreakerGrandJunction(@thetie);
  # note( $ties->logv() );
  is( $allintie->{'winner'}, 'PISTACHIO',
    'GrandJunction Method goes to fallback.' );
  note('Verify fallback with the tied TWEEDLES set');
  my $tweedles =
    Vote::Count->new( BallotSet => read_ballots('t/data/tweedles.txt'), );
  $tweedles->TieBreakerFallBackPrecedence(1);
  for my $method (qw /borda topcount approval grandjunction borda_all/) {
    is(
      $tweedles->TieBreaker(
        $method, $tweedles->Active(), $tweedles->GetActiveList
      ),
      ('TWEEDLE_THREE'),
      "fallback from $method picks precedence winner"
    );
  }

  $tweedles->PrecedenceFile('t/data/tweedlesprecedence2.txt');
  # Coverage: Making sure the trigger is tested when changing precedence file.
  $tweedles->TieBreakerFallBackPrecedence(1);
  for my $method (qw /borda topcount approval grandjunction borda_all/) {
    is(
      $tweedles->TieBreaker(
        $method, $tweedles->Active(), $tweedles->GetActiveList
      ),
      ('TWEEDLE_DUM'),
      "fallback from $method picks winner with different precedence file"
    );
  }
  my $method = 'all';
  is_deeply(
    [
      $tweedles->TieBreaker(
        $method,
        {
          TWEEDLE_DEE   => 1,
          TWEEDLE_DUM   => 1,
          TWEEDLE_TWO   => 1,
          TWEEDLE_THREE => 1
        },
        $tweedles->GetActiveList()
      )
    ],
    [],
    "fallback from all returns list of choices in tie"
  );
  $method = 'none';
  is_deeply(
    [
      $tweedles->TieBreaker(
        $method,
        {
          TWEEDLE_DEE   => 1,
          TWEEDLE_DUM   => 1,
          TWEEDLE_TWO   => 1,
          TWEEDLE_THREE => 1
        },
        $tweedles->GetActiveList()
      )
    ],
    [qw/TWEEDLE_DEE TWEEDLE_DO TWEEDLE_DUM TWEEDLE_THREE TWEEDLE_TWO/],
    "fallback from all returns list of choices in tie"
  );
};

subtest 'UntieList' => sub {
  my $E = Vote::Count->new(
    BallotSet                    => read_ballots('t/data/ties1.txt'),
    TieBreakMethod               => 'approval',
    PrecedenceFile               => 't/data/tiebreakerprecedence1.txt',
    TieBreakerFallBackPrecedence => 1,
  );
  my @tied = qw( CARAMEL STRAWBERRY CHOCCHUNK PISTACHIO ROCKYROAD RUMRAISIN );
  my @untied = $E->UnTieList( 'approval', @tied );
  my @expect =
    qw( ROCKYROAD PISTACHIO CARAMEL RUMRAISIN STRAWBERRY CHOCCHUNK );
  is_deeply( \@untied, \@expect,
    'correct sort order of choices per approval then precedence' );

  @untied = $E->UnTieList( 'precedence', @tied );
  @expect = qw( PISTACHIO ROCKYROAD CARAMEL RUMRAISIN CHOCCHUNK STRAWBERRY);
  is_deeply( \@untied, \@expect,
    'correct sort order of choices per precedence only' );
  $E->{'BallotSet'}{'ballots'}{'STRAWBERRY'} = {
    count     => 2,
    votevalue => .2,
    votes     => ["STRAWBERRY"]
  };
  @untied = $E->UnTieList( 'approval', @tied );
  @expect = qw( ROCKYROAD STRAWBERRY PISTACHIO CARAMEL RUMRAISIN CHOCCHUNK );
  is_deeply( \@untied, \@expect,
    'modified order when fractional vote is added to a choice' );
};

done_testing();
