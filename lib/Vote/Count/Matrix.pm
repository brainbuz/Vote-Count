use strict;
use warnings;
use 5.026;
use feature qw /postderef signatures/;

package Vote::Count::Matrix;
use Moose;

no warnings 'experimental';
# use List::Util qw( min max );
# use Vote::Count::RankCount;
# use Try::Tiny;
use Data::Printer;

has BallotSet => (
  is => 'ro',
  required => 1,
  isa => 'HashRef',
);

has BallotSetType => (
  is => 'ro',
  isa => 'Str',
  default => 'rcv',
);

has Active => (
  is => 'rw',
  isa => 'ArrayRef',
  builder => 'Vote::Count::Matrix::_buildActive',
  lazy => 1,
);

sub _buildActive ( $self ) {
  return [ keys $self->BallotSet->{'choices'}->%* ] ;
}

sub _conduct_pair ( $ballotset, $A, $B ) {
  my $ballots = $ballotset->{'ballots'};
  my $countA  = 0;
  my $countB  = 0;
FORVOTES:
  for my $b ( keys $ballots->%* ) {
    for my $v ( values $ballots->{$b}{'votes'}->@* ) {
      if    ( $v eq $A ) {
        $countA += $ballots->{$b}{'count'};
        next FORVOTES }
      elsif ( $v eq $B ) {
        $countB += $ballots->{$b}{'count'};
        next FORVOTES }
    }
  } # FORVOTES
  my %retval = (
    $A        => $countA,
    $B        => $countB,
    'tie'     => 0,
    'winner'  => '',
    'loser'   => '',
    'margin'  => abs( $countA - $countB )
    );
  if ( $countA == $countB ) {

    # tiebreak will happen here.
    $retval{'winner'} = '';
    $retval{'tie'}    = 1;
  }
  elsif ( $countA > $countB ) {
    $retval{'winner'} = $A;
    $retval{'loser'}  = $B;
  }
  elsif ( $countB > $countA ) {
    $retval{'winner'} = $B;
    $retval{'loser'}  = $A;
  }
  return \%retval;
}

sub BUILD  {
  my $self = shift;
  my $results = {};
  my $ballotset = $self->BallotSet();
  my @choices =  @{$self->Active} ;
  while ( scalar(@choices )) {
    my $A = shift @choices;
    for my $B ( @choices ) {
      my $result = Vote::Count::Matrix::_conduct_pair(
        $ballotset , $A, $B );
      # Each result has two hash keys so it can be found without
      # having to try twice or sort the names for a single key.
      $results->{$A}{$B} = $result;
      $results->{$B}{$A} = $result;
    }
  }
  $self->{'Matrix'} = $results;
}

1;