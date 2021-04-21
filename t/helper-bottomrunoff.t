#!/usr/bin/env perl

use 5.022;
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
use Vote::Count::Helper::BottomRunOff;

use feature qw /postderef signatures/;
no warnings 'experimental';

use Data::Printer;

my $B1 =  Vote::Count->new(
  BallotSet => read_ballots('t/data/biggerset1.txt'),
    TieBreakerFallBackPrecedence => 0 );
my $B2 = Vote::Count->new(
  BallotSet => read_ballots( 't/data/biggerset1.txt'),
  PrecedenceFile => 't/data/biggerset1precedence.txt',
  TieBreakerFallBackPrecedence => 1 );
my $Invert = Vote::Count->new(
  BallotSet => read_ballots( 't/data/tcinvertapproval.txt'),
  PrecedenceFile => 't/data/tcinvertapproval.prec.txt',
  TieBreakMethod => 'precedence' );

like(
  dies { BottomRunOff( $B1 ) },
  qr/TieBreakerFallBackPrecedence must be enabled/,
  "BottomRunOff dies if Precedence isnt available."
);

my $eliminate = BottomRunOff( $B2 );
my $etable = qq/Elimination Runoff:
| Rank | Choice    | Votes |
|------|-----------|-------|
| 1    | RUMRAISIN | 36    |
| 2    | ROCKYROAD | 21    |
/;
is_deeply( BottomRunOff( $B2 ),
 { loser => 'ROCKYROAD', continuing => 'RUMRAISIN', runoff => $etable },
 'BottomRunOff picked the winner and loser and had the right message'
 );

my $B2active = $B2->Active();

note( 'Delete some of the bottom choices');
for my $loser ( qw( ROCKYROAD RUMRAISIN STRAWBERRY TOAD) ) {
  delete $B2active->{ $loser };
}
my $r = BottomRunOff( $B2 );
is( $r->{'continuing'}, 'CARAMEL', 'check continuing after some eliminations');
is( $r->{'loser'}, 'SOGGYCHIPS', 'check the new loser too');

note( 'Delete more of the bottom choices');
for my $loser ( qw( CARAMEL SOGGYCHIPS CHOCOANTS VOMIT) ) {
  delete $B2active->{ $loser };
}

$r = BottomRunOff( $B2 );
is( $r->{'continuing'}, 'CHOCOLATE', 'check continuing after more eliminations');
is( $r->{'loser'}, 'PISTACHIO', 'check the new loser too');

note( 'Now checking with Data where the ranking of choices is inverted between
topcount and approval!');
$r = BottomRunOff( $Invert, 'TopCount' );
is( $r->{'continuing'}, 'STRAWBERRY', 'With these choices STRAWBERRY beats');
is( $r->{'loser'}, 'CARAMEL', 'CARAMEL');
$r = BottomRunOff( $Invert, 'Approval' );
note( 'switching to approval changes who is at the bottom:');
is( $r->{'continuing'}, 'VANILLA', 'With approval VANILLA beats');
is( $r->{'loser'}, 'CHOCOLATE', 'CHOCOLATE');
note( 'now reduce to 2 choices');
delete $Invert->{Active}{'CHOCOLATE'};
delete $Invert->{Active}{'STRAWBERRY'};

is_deeply(
  BottomRunOff( $Invert ),
  BottomRunOff( $Invert, 'Approval' ),
  'with just two choices topcount and approval hold the same runoff'
);
$r = BottomRunOff( $Invert );
is( $r->{'continuing'}, 'CARAMEL', 'with just 2 CARAMEL continues,');
is( $r->{'loser'}, 'VANILLA', 'VANILLA loses,');

note( 'now leave only one choice' );
delete $Invert->{Active}{'VANILLA'};
$r = BottomRunOff( $Invert );
is( $r->{'continuing'}, 'CARAMEL', 'only 1 choice remains, so wins runoff');
is( $r->{'loser'}, '', 'loser is the empty string with only 1 choice');

done_testing();
