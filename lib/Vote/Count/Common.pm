use strict;
use warnings;
use 5.024;

package Vote::Count::Common;
use Moose::Role;

use feature qw /postderef signatures/;
no warnings 'experimental';

use Storable 3.15 'dclone';
use Path::Tiny;

# ABSTRACT: Role shared by Count and Matrix for common functionality. See Vote::Count Documentation.

our $VERSION='1.212';

=head1 NAME

Vote::Count::Common

=head1 VERSION 1.212

=head1 Synopsis

This Role is consumed by Vote::Count and Vote::Count::Matrix. It provides common methods for the Active Set.

=cut

has 'BallotSet' => ( is => 'ro', isa => 'HashRef', required => 1 );

has 'Active' => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_defaultactive',
);

has 'VoteValue' => (
  is      => 'ro',
  isa     => 'Int',
  default => 1,
);

has 'WithdrawalList' => (
  is      => 'rw',
  isa     => 'Str',
  required => 0,
  );

sub GetChoices ( $self ) {
  return sort keys( $self->BallotSet()->{'choices'}->%* );
}

sub _defaultactive ( $self ) {
  my $active = dclone $self->BallotSet()->{'choices'} ;
  if ( $self->WithdrawalList ) {
    for my $w (path( $self->WithdrawalList )->lines({ chomp => 1})) {
      delete $active->{$w};
    }
  }
  return $active;
}

sub SetActive ( $self, $active ) {
  # Force deref
  $self->{'Active'} = dclone $active;
  # if there is a child PairMatrix, update it too.
  if ( defined $self->{'PairMatrix'} ) {
    $self->{'PairMatrix'}{'Active'} = $self->{'Active'};
  }
}

sub ResetActive ( $self ) {
  $self->{'Active'} = $self->_defaultactive();
}

# I was typing the equivalent too often. made a method.
sub SetActiveFromArrayRef ( $self, $active ) {
  $self->SetActive( { map { $_ => 1 } $active->@* } );
}

sub GetActive ( $self ) {
  # Force deref
  my $active = $self->Active();
  return dclone $active;
}

# this deref also happens a lot
sub GetActiveList( $self ) {
  return ( sort( keys( $self->Active->%* ) ) );
}

sub Defeat ( $self, $choice ) {
  delete $self->{'Active'}{$choice};
}

sub VotesCast ( $self ) {
  return $self->BallotSet()->{'votescast'};
}

sub VotesActive ( $self ) {
  unless ( $self->BallotSet()->{'options'}{'rcv'} ) {
    die "VotesActive Method only supports rcv";
  }
  my $set         = $self->BallotSet();
  my $active      = $self->Active();
  my $activeCount = 0;
LOOPVOTESACTIVE:
  for my $B ( values $set->{ballots}->%* ) {
    for my $V ( $B->{'votes'}->@* ) {
      if ( defined $active->{$V} ) {
        $activeCount += $B->{'count'};
        next LOOPVOTESACTIVE;
      }
    }
  }
  return $activeCount;
}

sub BallotSetType ( $self ) {
  if ( $self->BallotSet()->{'options'}{'rcv'} ) {
    return 'rcv';
  }
  elsif ( $self->BallotSet()->{'options'}{'range'} ) {
    return 'range';
  }
  else {
    die "BallotSetType is undefined or unknown type.";
  }
}

sub GetBallots ( $self ) {
  return $self->BallotSet()->{'ballots'};
}

1;

=head1 Usage

This role is consumed by Vote::Count and Vote::Count::Matrix, providing a common set of functions to all Vote::Count objects.

=head1 new

The only required parameter is BallotSet. The BallotSet is provided by L<Vote::Count::ReadBallots>, you may place the BallotSet in a variable or more typically read it from within the new method.

  use Vote::Count;
  use Vote::Count::ReadBallots;
  my $Election = Vote::Count->new( BallotSet => read_ballots( $ballotfile ) );

=head3 Optional Paramters to Vote::Count

=head4 Active

Optionally the ActiveSet can be set via new the ActiveSet

=head4 LogTo

Sets a path and Naming pattern for writing logs with the WriteLogs method.

  'LogTo' => '/loggingI<path/election>name'

The WriteLogs method will write the logs appending '.brief', '.full', and '.debug' for the three logs where brief is a summary written with the logt (log terse) method, the full transcript log written with logv, and finally the debug log written with logd. Each higher log level captures all events of the lower log levels.

The default log location is '/tmp/votecount'.

When logging from your methods, use logt for events that produce a summary, use logv for events that should be in the full transcript such as round counts, and finally debug is for events that may be helpful in debugging but which should not be in the transcript.


=head3 Active Sets

Active sets are typically represented as a Hash Reference where the keys represent the active choices and the value is true. The VoteCount Object contains an Active Set which can be Accessed via the Active() method which will return a reference to the Active Set (changing the reference will change the active set). The GetActive and SetActive methods do not preserve any reference links and should be preferred. GetActiveList returns the Active Set as a sorted list.

Many Components will take an argument for $activeset or default to the current Active set of the Vote::Count object, which will default to the Choices defined in the BallotSet.


=head1 Vote::Count Methods

Most of these are provided by the Role Common and available directly in both Matrix objects and Vote::Count Objects. Vote::Count objects create a child Matrix object: PairMatrix.


=head3 new

Arguments to new

=head3 Active

Get Active Set as HashRef to the active set. Changing the new HashRef will change the internal Active Set, GetActive is recommended as it will return a HashRef that is a copy instead.


=head3 GetActive

Returns a hashref containing a copy of the Active Set.


=head3 GetActiveList

Returns a simple array of the members of the Active Set.


=head3 ResetActive

Sets the Active Set to the full choices list of the BallotSet.


=head3 SetActive

Sets the Active Set to provided HashRef. The values to the hashref should evaluate as True.


=head3 SetActiveFromArrayRef

Same as SetActive except it takes an ArrayRef of the choices to be set as Active.


=head3 BallotSet

Get BallotSet


=head3 PairMatrix

Get a Matrix Object for the Active Set. Generated and cached on the first request.


=head3 UpdatePairMatrix

Regenerate and cache Matrix with current Active Set.


=head3 VotesCast

Returns the number of votes cast.


=head3 VotesActive

Returns the number of non-exhausted ballots based on the current Active Set.


















=head3 new

Has the following Attributes:

=head4 WithdrawalList

A text file containing choices 1 per line that are withdrawn. Use when a choice may be included in the ballots but should be treated as not-present. Removing a choice from the choices list in a Ballot File will generate an exception from ReadBallots if it appears on any Ballots. Withdrawing a choice will exclude it from the Active Set if it is present in the Ballots.

=head4 VoteValue

Use to set a Vote Value for methods that weight votes. The default value is 1.

=head3 Active

Get Active Set as HashRef to the active set. Changing the new HashRef will change the internal Active Set, GetActive is recommended as it will return a HashRef that is a copy instead.

=head3 GetActive

Returns a hashref containing a copy of the Active Set.

=head3 Choices

Returns an array of all of the Choices in the Ballot Set.

=head3 GetActiveList

Returns a simple array of the members of the Active Set.

=head3 ResetActive

Sets the Active Set to the full choices list of the BallotSet.

=head3 SetActive

Sets the Active Set to provided HashRef. The values to the hashref should evaluate as True.

=head3 SetActiveFromArrayRef

Same as SetActive except it takes an ArrayRef of the choices to be set as Active.

=head3 Defeat

Remove $choice from current Active List.

  $Election->Defeat( $choice );

=head3 BallotSet

Get BallotSet

=head3 GetBallots

Get just the Ballots from the BallotSet.

=head3 PairMatrix

Get a Matrix Object for the Active Set. Generated and cached on the first request.


=head3 UpdatePairMatrix

Regenerate and cache Matrix with current Active Set.


=head3 VotesCast

Returns the number of votes cast.


=head3 VotesActive

Returns the number of non-exhausted ballots based on the current Active Set.

=head3 VoteValue

Sets a VoteValue for use in weighted systems like STV. The default value is 1. Approval and TopCount are aware of VoteValue for RCV ballots.

=cut

#FOOTER

=pod

BUG TRACKER

L<https://github.com/brainbuz/Vote-Count/issues>

AUTHOR

John Karr (BRAINBUZ) brainbuz@cpan.org

CONTRIBUTORS

Copyright 2019-2021 by John Karr (BRAINBUZ) brainbuz@cpan.org.

LICENSE

This module is released under the GNU Public License Version 3. See license file for details. For more information on this license visit L<http://fsf.org>.

=cut

