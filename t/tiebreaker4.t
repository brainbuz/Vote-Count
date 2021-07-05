#!/usr/bin/env perl

use 5.024;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test2::Tools::Exception qw/dies lives/;
use File::Temp qw/tempfile tempdir/;
# use Test::Exception;
use Carp;
# use Data::Dumper;
use Data::Printer;

use Path::Tiny;
# use Storable 'dclone';

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

use feature qw /postderef signatures/;
no warnings 'experimental';

unlink '/tmp/vc.debug';

=pod
subtest 'Exceptions' => sub {

  like(
    dies {
      my $z =
        Vote::Count->new( BallotSet => read_ballots('t/data/ties1.txt'), );
      $z->UnTieActive( ranking1 => 'topcount' );
    },
    qr/TieBreakerFallBackPrecedence/,
    "Precedence must be method or fallback to use UntieActive"
  );

  like(
    dies {
      my $z =
        Vote::Count->new( BallotSet => read_ballots('t/data/ties1.txt'), );
      $z->UnTieList( ranking1 => 'TopCount', tied => [ 'BANANA', 'FUDGE' ] );
    },
    qr/TieBreakerFallBackPrecedence/,
    "Precedence must be method or fallback to use UnTieList"
  );

  like(
    dies {
      my $z =
        Vote::Count->new( BallotSet => read_ballots('t/data/ties1.txt'),
          TieBreakMethod => 'Precedence');
    },
    qr/Precedence File must be defined/,
    "Using Precedence without specifying Precedence file is fatal"
  );

  like(
    dies {
      my $ties = Vote::Count->new(
        BallotSet => read_ballots('t/data/ties1.txt'), );
      $ties->PrecedenceFile('t/data/tiebreakerprecedence2.txt');
      $ties->TieBreaker( $ties->TieBreakMethod(),
        $ties->Active(), qw( FUDGESWIRL CARAMEL) );
    },
    qr/undefined tiebreak method/,
     "undefined tiebreak method is fatal when tiebreaker is called."
  );
};

subtest 'bad untie methods' => sub {

  for my $A (
    { ranking1 => undef, test => 'missing', tested => 'ranking1 undef'},
    { ranking1 => 'bucklin', ranking2 => '', test => 'bucklin', tested => 'ranking1 is unavailable ranking' },
    { ranking1 => 'borda', ranking2 => 'bucklin', test => 'bucklin', tested => 'ranking2 is unavailable ranking' }
  ) {
    my $z = Vote::Count->new(
        BallotSet => read_ballots('t/data/ties1.txt'),
        TieBreakerFallBackPrecedence => 1 );
    like(
      dies { $z->UnTieActive( ranking1 => $A->{'ranking1'}, ranking2 => $A->{'ranking2'} ) },
      qr/$A->{'test'}/,
      "Tested ${\ $A->{'tested'} } -- RegexMatch /${\ $A->{'test'} }/"
    );
  }

  for my $B (
    { ranking1 => 'borda', ranking2 => undef, tested => 'ranking2 undef which should live' },
  ) {
    my $z = Vote::Count->new(
        BallotSet => read_ballots('t/data/ties1.txt'),
        TieBreakerFallBackPrecedence => 1 );
    ok(
      lives { $z->UnTieActive( ranking1 => $B->{'ranking1'}, ranking2 => $B->{'ranking2'} ) },
      "Tested ${\ $B->{'tested'} }"
    );
  }
};
=cut

todo 'test precedence with matrix and pairmatrix' => sub {
  my $t3 = Vote::Count->new(
    BallotSet => read_ballots('t/data/ties3.txt'),
    PrecedenceFile => 't/data/ties3precedence.txt',
    TieBreakMethod => 'Precedence',
    TieBreakerFallBackPrecedence => 1,
  );
  # use Carp::Always;
  note $t3->PairMatrix()->MatrixTable();
  # p $t3->{'PairMatrix'};
  note $t3->PairMatrix()->TieBreakerFallBackPrecedence();

};
ok 1;

done_testing;
