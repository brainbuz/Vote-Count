use strict;
use warnings;
use 5.026;
use feature qw /postderef signatures/;

package Vote::Count;
use namespace::autoclean;
use Moose;


no warnings 'experimental';

has 'ballotset' => ( is => 'ro', isa => 'HashRef' );
has 'ballotsettype' => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  builder => '__builder_ballotsettype__',
);

sub __builder_ballotsettype__ ( $self ) {
  if ( $self->{'ballotset'}{'options'}{'rcv'} ) {
    $self->{'ballotsettype'} = 'rcv';
  }
  elsif ( $self->{'ballotset'}{'options'}{'range'} ) {
    { $self->{'ballotsettype'} = 'range' }
  }
  else {
    die 'ballotset data missing option value of range or rcv';
  }
}

with 'Vote::Count::Approval', 'Vote::Count::TopCount';

__PACKAGE__->meta->make_immutable;
1;

=pod

how I'm going to handle various types

Range will have a choice of 2 methods to convert to rcv:
  expande ties by Approval
  Divide ties ie 4 ballots [ a, b ] will split to 2 [ a ] and 2 [ b ]

Won't directly handle Approval

Plurality will be treated as an RCV set where all voters bullet voted.