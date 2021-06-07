#!/usr/bin/env perl

use 5.024;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Test2::Tools::Exception qw/dies lives/;
use File::Temp qw/tempfile tempdir/;
# use Vote::Count::Charge::Utility qw/ WeightedTable /;
# use Test::Exception;
use Carp;
use Data::Dumper;

use Path::Tiny;
# use Storable 'dclone';

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

use feature qw /postderef signatures/;
no warnings 'experimental';
use Data::Printer;

subtest 'UnTieList' => sub {
  my $E = Vote::Count->new(
    BallotSet                    => read_ballots('t/data/ties1.txt'),
    TieBreakMethod               => 'approval',
    PrecedenceFile               => 't/data/tiebreakerprecedence1.txt',
    TieBreakerFallBackPrecedence => 1,
  );

  is_deeply( [$E->UnTieList( ranking1 => 'precedence', tied => ['VANILLA'])], ['VANILLA'], 'precedence with 1 just returned it');
  # $E->TieBreakMethod( 'approval');
  is_deeply( [
    $E->UnTieList( ranking1 => 'Approval', tied => ['CHOCOLATE'] ) ],
    ['CHOCOLATE'],
    'approval with 1 just returned it');

  my @tied = qw( CARAMEL CHERRY STRAWBERRY CHOCOLATE RUMRAISIN );
  my %args = ();

  $E->TieBreakMethod( 'precedence');
  %args = ( 'ranking1' => 'precedence', 'tied' => \@tied );
  is_deeply(
    [ $E->UnTieList( %args )],
    [ qw( CARAMEL RUMRAISIN CHERRY CHOCOLATE STRAWBERRY)],
    'precedence tiebreaker sorted a longer tie into the right order');

  # $E->TieBreakMethod( 'Approval');
  is_deeply(
    [ $E->UnTieList( ranking1 => 'Approval', tied => \@tied )],
    [ qw( CHERRY CHOCOLATE CARAMEL RUMRAISIN STRAWBERRY)],
    'approval tiebreaker with sub-resolution by precedence');

  is_deeply(
    [ $E->UnTieList( ranking1 => 'Approval', tied => ['CHOCCHUNK', 'STRAWBERRY'] )],
    [ qw( STRAWBERRY CHOCCHUNK )],
    'approval resolves 2 choices');

  is_deeply(
    [ $E->UnTieList( ranking1 => 'Approval', tied => ['STRAWBERRY', 'CHOCCHUNK'] )],
    [ qw( STRAWBERRY CHOCCHUNK )],
    'approval resolved same 2 choices with order switched');

  # $E->TieBreakMethod( 'TopCount');
  my %tie = map { $_ => 1 } ( qw/CHERRY CHOCOLATE CARAMEL RUMRAISIN STRAWBERRY/);
  note $E->TopCount(\%tie)->RankTable();
  note $E->Approval(\%tie)->RankTable();
  is_deeply(
    [ $E->UnTieList( ranking1 => 'TopCount', tied => \@tied , dump => 1 )],
    [ qw( CHERRY CHOCOLATE CARAMEL RUMRAISIN STRAWBERRY )],
    'topcount tiebreaker with sub-resolution by precedence');

  # p $E->TopCount()->RankTable();
  # p $E->Approval()->RankTable();
  # unwind approval: CHERRY:CHOCOLATE CARAMEL:RUMRAISIN STRAWBERRY

  # resolve approval STRAWBERRY CHOCCHUNK

  # resolve first then fallback precedence topcount
  #  STRAWBERRY  CHERRY:CHOCOLATE:CARAMEL:RUMRAISIN


  # my
  # @tied = qw( CARAMEL STRAWBERRY CHOCCHUNK PISTACHIO ROCKYROAD RUMRAISIN );
  # my @untied = $E->UnTieList( 'Approval', @tied );
  # my @expect =
  #   qw( ROCKYROAD PISTACHIO CARAMEL RUMRAISIN STRAWBERRY CHOCCHUNK );
  # is_deeply( \@untied, \@expect,
  #   'correct sort order of choices per approval then precedence' );

  # @untied = $E->UnTieList( 'precedence', @tied );
  # @expect = qw( PISTACHIO ROCKYROAD CARAMEL RUMRAISIN CHOCCHUNK STRAWBERRY);
  # is_deeply( \@untied, \@expect,
  #   'correct sort order of choices per precedence only' );
  # $E->{'BallotSet'}{'ballots'}{'STRAWBERRY'} = {
  #   count     => 2,
  #   votevalue => .2,
  #   votes     => ["STRAWBERRY"]
  # };
  # @untied = $E->UnTieList( 'Approval', @tied );
  # @expect = qw( ROCKYROAD STRAWBERRY PISTACHIO CARAMEL RUMRAISIN CHOCCHUNK );
  # is_deeply( \@untied, \@expect,
  #   'modified order when fractional vote is added to a choice' );
};

done_testing();
=pod

my $D = Vote::Count->new(
  BallotSet                    => read_ballots('t/data/ties1.txt'),
  TieBreakerFallBackPrecedence => 1,
  PrecedenceFile               => 't/data/tiebreakerprecedence1.txt',
);

subtest 'UntieActive just precedence' => sub {

  my $var1 = {
    FUDGESWIRL => 1,
    PISTACHIO  => 2,
    ROCKYROAD  => 3,
    MINTCHIP   => 4,
    CARAMEL    => 5,
    RUMRAISIN  => 6,
    BUBBLEGUM  => 7,
    CHERRY     => 8,
    CHOCCHUNK  => 9,
    VANILLA    => 10,
    CHOCOLATE  => 11,
    STRAWBERRY => 12,
  };
  my $untied = eval { $D->UntieActive( 'precedence' ) };
  for my $x ( sort keys %{$var1} ) {
    is( abs( $untied->RawCount()->{$x} ), $var1->{$x}, $x );
  }

};


subtest 'UntieActive topcount, topcount precedence' => sub {
  note( 'untieactive should imply precedence as the second argument');
  my $var1 = {
    FUDGESWIRL => 1,
    VANILLA    => 2,
    PISTACHIO  => 3,
    ROCKYROAD  => 4,
    MINTCHIP   => 5,
    RUMRAISIN  => 6,
    BUBBLEGUM  => 7,
    CHOCCHUNK  => 8,
    CARAMEL    => 9,
    CHERRY     => 10,
    CHOCOLATE  => 11,
    STRAWBERRY => 12,
  };
  my $u1 = eval { $D->UntieActive( 'TopCount', 'precedence' ) };
  my $u2 = eval { $D->UntieActive( 'TopCount' ) };
  is_deeply( $u1, $u2, 'runs with provided and implied second argument have same result');
  for my $x ( sort keys %{$var1} ) {
    is( abs( $u1->RawCount()->{$x} ), $var1->{$x}, $x );
  }
};

subtest 'UntieActive TopCount approval precedence' => sub {
  my $var2 = {
    FUDGESWIRL => 1,
    VANILLA    => 2,
    MINTCHIP   => 3,
    ROCKYROAD  => 4,
    PISTACHIO  => 5,
    RUMRAISIN  => 6,
    BUBBLEGUM  => 7,
    CHOCCHUNK  => 8,
    CHERRY     => 9,
    CHOCOLATE  => 10,
    CARAMEL    => 11,
    STRAWBERRY => 12,
  };
  my $untied = eval { $D->UntieActive( 'TopCount', 'Approval' ) };
  for my $x ( sort keys %{$var2} ) {
    is( abs( $untied->RawCount()->{$x} ), $var2->{$x}, $x );
  }
};



subtest 'UntieActive Borda topcount precedence' => sub {
  my $var3 = {
    MINTCHIP   => 1,
    FUDGESWIRL => 2,
    VANILLA    => 3,
    BUBBLEGUM  => 4,
    CHERRY     => 5,
    CHOCOLATE  => 6,
    ROCKYROAD  => 7,
    PISTACHIO  => 8,
    RUMRAISIN  => 9,
    CARAMEL    => 10,
    STRAWBERRY => 11,
    CHOCCHUNK  => 12,
  };
  my $untied = $D->UntieActive( 'Borda', 'TopCount' );
  for my $x ( sort keys %{$var3} ) {
    is( abs( $untied->RawCount()->{$x} ), $var3->{$x}, $x );
  }
};

my %var4 = do {
  my $ctr = 0;
  map { $_ => ++$ctr }
    ( split /\n/, path('t/data/tiebreakerprecedence1.txt')->slurp );
};
my $prec = $D->UntieActive('Precedence');
is_deeply( $prec->HashWithOrder(),
  \%var4, 'UntieActive hashwithorder matches the raw precedence file' );
delete $D->{'Active'}{'FUDGESWIRL'};
delete $D->{'Active'}{'VANILLA'};
my $afterelim = $D->UntieActive( 'TopCount', 'Approval' )->HashByRank();
is( scalar( keys $afterelim->%* ),
  10, 'With 2 choices eliminated UntieActive had 2 fewer choices' );
is( $afterelim->{1}[0], 'CHERRY', 'new leader after the eliminations' );
is( $afterelim->{2}[0],
  'MINTCHIP', 'check a choice that moved down rank after elimination' );

done_testing;
