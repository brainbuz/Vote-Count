use strict;
use warnings;
use 5.024;
use feature qw /postderef signatures/;

# ABSTRACT: toolkit for implementing voting methods.

package Vote::Count;
use namespace::autoclean;
use Moose;

use Data::Dumper;
use Time::Piece;
use Path::Tiny;
use Vote::Count::Matrix;
use Vote::Count::ReadBallots qw( read_ballots read_range_ballots);
# use Storable 3.15 'dclone';

no warnings 'experimental';

our $VERSION='1.21';

=head1 NAME

Vote::Count

=head1 VERSION 1.21

=cut

# ABSTRACT: Parent Module for Vote::Count. Toolkit for vote counting.

sub _buildmatrix ( $self ) {
  my $tiebreak =
    defined( $self->TieBreakMethod() )
    ? $self->TieBreakMethod()
    : 'none';
  return Vote::Count::Matrix->new(
    BallotSet      => $self->BallotSet(),
    Active         => $self->Active(),
    TieBreakMethod => $tiebreak,
    LogTo          => $self->LogTo() . '_matrix',
  );
}

sub BUILD {
  my $self = shift;
  # Verbose Log
  $self->{'LogV'} = localtime->cdate . "\n";
  # Debugging Log
  $self->{'LogD'} = qq/Vote::Count Version $VERSION\n/;
  $self->{'LogD'} .= localtime->cdate . "\n";
  # Terse Log
  $self->{'LogT'} = '';
}

# load the roles providing the underlying ops.
with
  'Vote::Count::Common',
  'Vote::Count::Approval',
  'Vote::Count::Borda',
  'Vote::Count::BottomRunOff',
  'Vote::Count::Floor',
  'Vote::Count::IRV',
  'Vote::Count::Log',
  'Vote::Count::Score',
  'Vote::Count::TieBreaker',
  'Vote::Count::TopCount',
  ;

__PACKAGE__->meta->make_immutable;
1;
