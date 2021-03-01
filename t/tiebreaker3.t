#!/usr/bin/env perl

use 5.022;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
use Test2::Tools::Exception qw/dies lives/;
use File::Temp qw/tempfile tempdir/;
# use Test::Exception;
use Carp;
use Data::Dumper;

use Path::Tiny;
# use Storable 'dclone';

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

use feature qw /postderef signatures/;
no warnings 'experimental';

todo 'UnTieList' => sub {
  my $E = Vote::Count->new(
    BallotSet                    => read_ballots('t/data/ties1.txt'),
    TieBreakMethod               => 'approval',
    PrecedenceFile               => 't/data/tiebreakerprecedence1.txt',
    TieBreakerFallBackPrecedence => 1,
  );

note Dumper $E->_precedence_sort( qw( CARAMEL STRAWBERRY CHOCCHUNK PISTACHIO ROCKYROAD RUMRAISIN ) )  ;
note Dumper $E->{'PRECEDENCEORDER'};

  my @tied = qw( CARAMEL STRAWBERRY CHOCCHUNK PISTACHIO ROCKYROAD RUMRAISIN );
  my @untied = $E->UnTieList( 'Approval', @tied );
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
  @untied = $E->UnTieList( 'Approval', @tied );
  @expect = qw( ROCKYROAD STRAWBERRY PISTACHIO CARAMEL RUMRAISIN CHOCCHUNK );
  is_deeply( \@untied, \@expect,
    'modified order when fractional vote is added to a choice' );
};

done_testing;

=pod

todo 'UnTieAll' => sub {

  like(
    dies {
      my $z =
        Vote::Count->new( BallotSet => read_ballots('t/data/ties1.txt'), );
      $z->UnTieAll( 1, 2 );
    },
    qr/TieBreakerFallBackPrecedence/,
    "TieBreakerFallBackPrecedence must be true to use UnTieAll"
  );

  my $D = Vote::Count->new(
    BallotSet                    => read_ballots('t/data/ties1.txt'),
    TieBreakerFallBackPrecedence => 1,
    PrecedenceFile               => 't/data/tiebreakerprecedence1.txt',
  );

  my $var2 = {
    FUDGESWIRL => 1,
    VANILLA    => 2,
    MINTCHIP   => 3,
    ROCKYROAD  => 4,
    PISTACHIO  => 5,
    RUMRAISIN  => 6,
    BUBBLEGUM  => 7,
    CHOCCHUNK  => 8,
    CARAMEL    => 9,
    CHERRY     => 10,
    CHOCOLATE  => 11,
    STRAWBERRY => 12
  };

  subtest 'TopCount approval precedence' => sub {
    my $untied = $D->UnTieAll( 'TopCount', 'approval' );
    for my $x ( keys %{$var2} ) {
      is( abs( $untied->RawCount()->{$x} ), $var2->{$x}, $x );
    }
  };

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
  subtest 'Borda topcount precedence' => sub {
    my $untied = $D->UnTieAll( 'Borda', 'topcount' );
    for my $x ( keys %{$var3} ) {
      is( abs( $untied->RawCount()->{$x} ), $var3->{$x}, $x );
    }
  };

};

done_testing();
