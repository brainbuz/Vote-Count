use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::Method::CondorcetDropping;

use namespace::autoclean;
use Moose;
extends 'Vote::Count';
# Brings the main Vote::Count Object in along with
# Topcount and other methods.
# with 'Vote::Count';
# with 'Vote::Count::Matrix';

our $VERSION='0.002';

=head1 NAME

Vote::Count::Method::CondorcetDropping

=head1 VERSION 0.000

=cut

# ABSTRACT: Methods which use simple dropping rules to resolve a Winnerless Condorcet Matrix.

#buildpod

#buildpod

no warnings 'experimental';
use List::Util qw( min max );
use YAML::XS;

use Vote::Count::Matrix;
# use Try::Tiny;
use Text::Table::Tiny 'generate_markdown_table';
use Data::Printer;
use Data::Dumper;

has 'Matrix' => (
  isa => 'Object',
  is => 'ro',
  lazy => 1,
  builder => '_newmatrix',
);

# DropStyle: whether to apply drop rule against
# all choices ('all') or the least winning ('leastwins').
has 'DropStyle' => (
  isa => 'Str',
  is => 'ro',
  default => 'leastwins',
);

sub _newmatrix ($self) {
  return Vote::Count::Matrix->new(
    'BallotSet' => $self->BallotSet()  );
}

sub RunCondorcetPLD ( $self, $active = undef ) {
  unless ( defined $active ) {
    $active = $self->BallotSet->{'choices'};
  }
  my $roundctr   = 0;
  my $maxround   = scalar( keys %{$active} );
  $self->logt( "Condorcet Dropping, Plurality Loser (Lowest TopCount) Rule.",
    'Choices: ', join( ', ', ( sort keys %{$active} ) ) );
PLDLOOP:
  until ( 0 ) {
    $roundctr++;
    die "PLDLOOP infinite stopped at $roundctr" if $roundctr > $maxround;
# First step on every round is to seek a majority winner.
    my $round = $self->TopCount($active);
    $self->logv( '---', "Round $roundctr TopCount", $round->RankTable() );
    my $majority = $self->EvaluateTopCountMajority( $round );
    if ( defined $majority->{'winner'} ) {
      return $majority->{'winner'};
    }
# No Majority? look for a Condorcet Winner.
    my $matrix = Vote::Count::Matrix->new(
      'BallotSet' => $self->BallotSet,
      'Active' => $active );
    $self->logv( '---', "Round $roundctr Pairings", $matrix->MatrixTable() );
    my $cw = $matrix->CondorcetWinner() || 0 ;
    if ( $cw ) {
      $self->logt( "Winner $cw");
      return $cw;
    }
    my $eliminated = $matrix->CondorcetLoser();
$self->logd( "eliminated ", YAML::XS::Dump($eliminated) );
    if( $eliminated->{'eliminations'}) {
      # tracking active between iterations of matrix.
      $active = $matrix->Active();
      # active changed, restart loop
      next PLDLOOP;
    }
    # no losers eliminated, then we go to topcount!
    my @jeapardy = ();
    if( $self->DropStyle eq 'leastwins') {
      my %scored = $matrix->_scorematrix()->%*;
      my $lowscore = min( values %scored );
      for my $A ( keys %{$active} ) {
        if ( $scored{ $A } == $lowscore ) {
          push @jeapardy, $A;
        }
      }
    } else { @jeapardy = keys %{$active} }
    my $lowest = $round->CountVotes();
    for my $j (@jeapardy) {
      $lowest = $round->{$j} if $round->{$j} < $lowest;
    }
    for my $j (@jeapardy) {
      if ( $round->{$j} == $lowest ) {
        delete $active->{$j}
      }
    }

  };#infinite PLDLOOP

  }


1;
