use strict;
use warnings;
use 5.026;
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

sub _buildbordaweight {
   return sub {
    my $x = shift ;
    if( $x > 5) { return 0 }
    return ( 6 - $x) }
  }

=pod

=head3 _boordashrinkballot( $ballotset, $active )

Takes a ballotset and active list and returns a
ballotset reduced to only the active choices. When
choices are removed later choices are promoted.

=cut

sub _boordashrinkballot ( $ballotset, $active ) {
  my $newballots = {};
  my %ballots = $ballotset->{'ballots'}->%* ;
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

sub _doboordacount( $BoordaTable, $weight) {
  my $BoordaCount = {};
  for my $c ( keys $BoordaTable->%*) {
    for my $rank ( keys $BoordaTable->{$c}->%* ) {
      $BoordaCount->{ $c } +=
        $BoordaTable->{$c}{$rank} * $weight->( $rank )
    }
  }
  return $BoordaCount;
}

sub Boorda ( $self, $active = undef ) {
  my %ballotset = $self->ballotset()->%*;
  my %ballots   = ();
  if ( defined $active ) {
    %ballots = %{_boordashrinkballot( \%ballotset, $active )};
  }
  else {
    %ballots = $ballotset{'ballots'}->%*;
    $active  = $ballotset{'choices'};
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
  return (
    Vote::Count::RankCount->Rank(
      _doboordacount( \%BoordaTable, $self->bordaweight() )
    ),
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