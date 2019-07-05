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
# use boolean;
use Data::Printer;

has BallotSet => (

)

# has TieBreakTable => (
#   is => 'ro',
#   isa => 'Object',
#   lazy => 1,
#   builder => '_buildtiebreaktable',
# );

# sub _buildtiebreaktable ( $self ) {
#   my ( $table, $discard ) = $self->Boorda();
#   return $table;
# }
# has 'bordaweight' => (
#   is => 'rw',
#   isa => 'CodeRef',
#   builder => '_buildbordaweight',
#   lazy => 1,
# );

# has 'bordadepth' => (
#   is => 'rw',
#   isa => 'Int',
#   default => 0,
# );

=pod

=head2 Populate

Populate Matrix for Pairwise methods.

=cut

sub Populate (
  $self,
  $active=[ keys $self->ballotset()->{'choices'}->%* ]
  ) {
  my $Matrix = {};
p $active;
  $self->{'Matrix'} = $Matrix;
}

1;