use strict;
use warnings;
use 5.026;
use feature qw /postderef signatures/;

package Vote::Count;
use namespace::autoclean;
use Moose;

use Data::Printer;

no warnings 'experimental';

has 'BallotSet' => ( is => 'ro', isa => 'HashRef' );
has 'BallotSetType' => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default =>  'rcv',
);

# floor rules:
# none, app5 5% approval, tc5 5% topchoice,
# tcapp = approval must be at least half leading topcount
# custom = pass coderef to CustomFloorRule

has 'FloorRule' => (
  is      => 'ro',
  isa     => 'Str',
  default =>  'app5',
);

has 'CustomFloorRule' => (
  is      => 'ro',
  isa     => 'CodeRef'
);


# load the roles providing the underlying ops.
with  'Vote::Count::Approval',
      'Vote::Count::TopCount',
      'Vote::Count::Boorda',
      'Vote::Count::Floor'
      ;

sub CountBallots ( $self ) {
  my $ballots = $self->BallotSet()->{'ballots'};
  my $numvotes = 0;
  for my $ballot ( keys $ballots->%* ) {
    $numvotes += $ballots->{$ballot}{'count'};
  }
  return $numvotes;
}

__PACKAGE__->meta->make_immutable;
1;

=pod

how I'm going to handle various types

Range will have a choice of 2 methods to convert to rcv:
  expande ties by Approval
  Divide ties ie 4 ballots [ a, b ] will split to 2 [ a ] and 2 [ b ]

Won't directly handle Approval

Plurality will be treated as an RCV set where all voters bullet voted.