use strict;
use warnings;
use 5.026;

use feature qw /postderef signatures/;

package VoteCount::TopCount::Rank;
no warnings 'experimental';

# RankTopCount Method returns an object
# The object needs to be defined in another class
# This class within the module for another class is only
# visble there, which is the only place it should be visible.

sub new ( $class, $ordered, $byrank, $top, $bottom ) {
  my $I = {
    'ordered' => $ordered,
    'byrank' => $byrank,
    'top' => $top,
    'bottom' => $bottom
  };
  return bless $I, $class;
}

sub hashwithorder ( $I ) { return $I->{'ordered'}->%* }
sub hashbyrank ( $I ) { return $I->{'byrank'}->%* }
sub arraytop ( $I ) { return $I->{'top'}->@* }
sub arraybottom ( $I ) { return $I->{'bottom'}->@* }


package VoteCount::TopCount;
use Moose::Role;

no warnings 'experimental';
use List::Util qw( min max );
use boolean;
use Data::Printer;

sub TopCount ( $self, $active=undef ) {
  my %ballotset = $self->ballotset()->%*;
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
  return \%topcount;
}

sub TopCountMajority ( $self, $topcount = undef, $active = undef ) {
  unless ( defined $topcount ) { $topcount = $self->TopCount($active) }
  my $numvotes = 0;
  my @choices  = keys $topcount->%*;
  for my $t (@choices) { $numvotes += $topcount->{$t} }
  my $thresshold = 1 + int( $numvotes / 2 );
  for my $t (@choices) {
    if ( $topcount->{$t} >= $thresshold ) {
      return (
        {
          votes      => $numvotes,
          thresshold => $thresshold,
          winner     => $t,
          winvotes   => $topcount->{$t}
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

sub RankTopCount ( $self, $topcount = undef, $active = undef ) {
  unless ( defined $topcount ) { $topcount = $self->TopCount($active) }
  my %tc      = $topcount->%*;    # destructive process needs to use a copy.
  my %ordered = ();
  my %byrank  = () ;
  my $pos = 0;
  my $maxpos = scalar( keys %tc ) ;
  while ( 0 < scalar( keys %tc ) ) {
    $pos++;
    my @vtc      = values %tc;
    my $max      = max @vtc;
    for my $k ( keys %tc ) {
      if ( $tc{$k} == $max ) {
        $ordered{$k} = $pos;
        delete $tc{ $k };
        if ( defined $byrank{$pos} ) {
          push @{ $byrank{$pos} }, $k;
        }
        else {
          $byrank{$pos} = [ $k ];
        }
      }
    }
    die "RankTopCount in infinite loop\n" if
      $pos > $maxpos ;
    ;
  }
  # %byrank[1] is arrayref of 1st position,
  # $pos still has last position filled, %byrank{$pos} is the last place.

  return VoteCount::TopCount::Rank->new(
    \%ordered, \%byrank, $byrank{1}, $byrank{ $pos} );
}



1;