use strict;
use warnings;
use 5.026;

use feature qw /postderef signatures/;

package Vote::Count::TopCount;
use Moose::Role;

no warnings 'experimental';
use List::Util qw( min max );
use Vote::Count::RankCount;
# use boolean;
# use Data::Printer;

sub TopCount ( $self, $active=undef ) {
  my %ballotset = $self->BallotSet()->%*;
  my %ballots = ( $ballotset{'ballots'}->%* );
  $active = $ballotset{'choices'} unless defined $active ;
  my %topcount = ( map { $_ => 0 } keys( $active->%* ));
TOPCOUNTBALLOTS:
    for my $b ( keys %ballots ) {
      my @votes = $ballots{$b}->{'votes'}->@* ;
      for my $v ( @votes ) {
        if ( defined $topcount{$v} ) {
          $topcount{$v} += $ballots{$b}{'count'};
          next TOPCOUNTBALLOTS;
        }
      }
    }
  return Vote::Count::RankCount->Rank( \%topcount );
}

sub TopCountMajority ( $self, $topcount = undef, $active = undef ) {
  unless ( defined $topcount ) { $topcount = $self->TopCount($active) }
  my $topc = $topcount->RawCount();
  my $numvotes = 0;
  my @choices  = keys $topc->%*;
  for my $t (@choices) { $numvotes += $topc->{$t} }
  my $thresshold = 1 + int( $numvotes / 2 );
  for my $t (@choices) {
    if ( $topc->{$t} >= $thresshold ) {
      return (
        {
          votes      => $numvotes,
          thresshold => $thresshold,
          winner     => $t,
          winvotes   => $topc->{$t}
        }
      );
    }
  }
  # No winner
  return (
    {
      votes      => $numvotes,
      thresshold => $thresshold
    }
  );
}

1;