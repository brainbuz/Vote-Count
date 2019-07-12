use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::Boorda;

use Moose::Role;

no warnings 'experimental';
use List::Util qw( min max );
use Vote::Count::RankCount;
# use Try::Tiny;
# use boolean;
# use Data::Printer;

has 'bordaweight' => (
  is => 'rw',
  isa => 'CodeRef',
  builder => '_buildbordaweight',
  lazy => 1,
);

has 'bordadepth' => (
  is => 'rw',
  isa => 'Int',
  default => 0,
);

=pod

=head1 Boorda Wieght

Boorda's original method assigned each position the
inverse if its position, ie in a 9 choice ballot
position 1 was worth 9, while position 9 was worth 1,
and position 8 was worth 2.

When Creating a VoteCount object the Boorda weight
may be set by passing a coderef. The coderef takes
two arguments. The first argument is the
position of the choice in question.
The second argument is the depth of the ballot. The
optional bordadepth attribute will set an arbitrary
depth. Some popular options such inversion ( where
choice $c becomes $c/1 then inverted to 1/$c) don't
need to know the depth. In such cases the coderef
should just ignore the second argument.

The default Weight when none are provided is Boorda's
original weight. If the boordadepth attribute is set
it will be followed.

=cut

sub _buildbordaweight {
   return sub {
    my ( $x, $y ) = @_ ;
    return ( $y +1 - $x) }
  }

=pod

=head3 Private Method _boordashrinkballot( $BallotSet, $active )

Takes a BallotSet and active list and returns a
BallotSet reduced to only the active choices. When
choices are removed later choices are promoted.

=cut

sub _boordashrinkballot ( $BallotSet, $active ) {
  my $newballots = {};
  my %ballots = $BallotSet->{'ballots'}->%* ;
  for my $b ( keys %ballots ) {
    my @newballot = ();
    for my $item ( $ballots{$b}{'votes'}->@* ) {
      if ( defined $active->{ $item }) {
        push @newballot, $item ;
      }
    }
    if (scalar( @newballot )) {
      $newballots->{$b}{'votes'} = \@newballot;
      $newballots->{$b}{'count'} =
    $ballots{$b}->{'count'};
    }
  }
  return $newballots;
}

sub _doboordacount( $self, $BoordaTable, $active) {
  my $BoordaCount = {};
  my $weight = $self->bordaweight;
  my $depth = $self->bordadepth
    ? $self->bordadepth
    : scalar( keys %{$active} );
  for my $c ( keys $BoordaTable->%*) {
    for my $rank ( keys $BoordaTable->{$c}->%* ) {
      $BoordaCount->{ $c } = 0 unless defined $BoordaCount->{ $c };
      $BoordaCount->{ $c } +=
        $BoordaTable->{$c}{$rank} *
        $weight->( $rank, $depth ) ;
    }
  }
  return $BoordaCount;
}

sub Boorda ( $self, $active = undef ) {
  my %BallotSet = $self->BallotSet()->%*;
  my %ballots   = ();
  if ( defined $active ) {
    %ballots = %{_boordashrinkballot( \%BallotSet, $active )};
  }
  else {
    %ballots = $BallotSet{'ballots'}->%*;
    $active  = $BallotSet{'choices'};
  }
  my %BoordaTable = ( map { $_ => {} } keys( $active->%* ) );
  for my $b ( keys %ballots ) {
    my @votes  = $ballots{$b}->{'votes'}->@*;
    my $bcount = $ballots{$b}->{'count'};
    for ( my $i = 0 ; $i < scalar(@votes) ; $i++ ) {
      my $c = $votes[$i];
      if ( defined $BoordaTable{$c} ) {
        $BoordaTable{$c}->{ $i + 1 } += $bcount;
      }
      else {
        $BoordaTable{$c}->{ $i + 1 } = $bcount;
      }
    }
  }
  my $BoordaCounted =
         _doboordacount(
           $self,
           \%BoordaTable,
           $active );
  return (
    Vote::Count::RankCount->Rank( $BoordaCounted ),
    \%BoordaTable
  );
}


# =pod

# =head3 RangeBoorda

# When applying Boorda to ranged voting the choices are to convert to rcv or to boorda
# count multiple choices at the same range the same. This method implements that latter.

# =cut

# sub RangeBoorda {
#   ...
# }


1;