use strict;
use warnings;
use 5.026;
use feature qw /postderef signatures/;

package Vote::Count;
use namespace::autoclean;
use Moose;


no warnings 'experimental';

has 'BallotSet' => ( is => 'ro', isa => 'HashRef' );
has 'BallotSetType' => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default =>  'rcv',
);


# load the roles providing the underlying ops.
with  'Vote::Count::Approval',
      'Vote::Count::TopCount',
      'Vote::Count::Boorda'
      ;

__PACKAGE__->meta->make_immutable;
1;

=pod

how I'm going to handle various types

Range will have a choice of 2 methods to convert to rcv:
  expande ties by Approval
  Divide ties ie 4 ballots [ a, b ] will split to 2 [ a ] and 2 [ b ]

Won't directly handle Approval

Plurality will be treated as an RCV set where all voters bullet voted.