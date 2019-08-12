use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::Method::CondorcetIRV;

use Exporter::Easy ( EXPORT => [ 'SmithSetIRV' ] );

# use namespace::autoclean;
# use Moose;
# extends 'Vote::Count';

our $VERSION='0.020';

=head1 NAME

Vote::Count::Method::CondorcetIRV

=head1 VERSION 0.020

=cut

# ABSTRACT: Simple Condorcet IRV Methods.

=pod

=head1 SYNOPSIS

  use Vote::Count::Method::CondorcetIRV;
  my $Election = .... a Vote::Count object
  $Election->SetActive( $activeset );
  # Benham Documented, not implemented
  ...
  # SmithSetIRV
  my $winner = SmithSetIRV( $Election );



=head1 Description

Provides Common Basic Condorcet-IRV Methods. These methods are simple and beat the leading Condorcet Methods on Later Harm.

The author of Vote::Count recomends serious consideration to these methods and Redaction for Later Harm Condorcet methods.

These methods can all be considered Sufficient in Resolvability, although specifiying a tie breaker is as always recommended.

The modules exports the available methods.

=head1 Recommendation

Benham with Immediate Loser Elimination is recommended by the author of Vote::Count for situations where Hand Counting is a requirement and Later Harm can be tolerated.

For situations where a simple method is required and Later Harm can be tolerated, the author of Vote::Count recommends SmithSet-IRV.

=head1 Benham

Returns the winner as soon as there is a Majority Winner or one of the choices is shown to be a Condorcet Winner. Because it is not necessary to produce a full matrix this method is easier to count than other Pairwise Condorcet Methods.

=head2 Criteria

=head3 Simplicity

Benham is easy to understand and is handcountable.

=head3 Later Harm

Benham has less Later Harm effect than many Condorcet Methods, but not a lot less.

=head3 Condorcet Criteria

Meets Condorcer Winner and Loser, fails the Smith Criteria.

=head3 Consistency

In so far as Benham will always elect a Condorcet Winner if present it is more consistent than IRV, when none is present it shares the consistency weaknesses of IRV.

=head2 Benham Handouct Process

Top Count the Ballots

Elect a Majority Winner

Start a sheet for each choice with a Wins and Losses Column. If you also count Approval, for each choice with lower Approval than the Top Count of another choice you can immediately mark the resolutions on the sheet.

Then starting with the Top Count Leader compare them to the next highest choice (that they haven't already been paired to) and pair them off, recording the result on the sheets. Continue pairing the winner of the contest to the next highest choice they haven't met yet, if both choices have a loss (to a choice which hasn't been eliminated) you may skip the pairing. Continue until every choice has at least 1 loss or a choice has defeated all others.

When a Condorcet Winner is found they are the winner.

If no Condorcet Winner is found, then remove the choice with the lowest Top Count. Repeat the search for a Condorcet Winner, now ignoring losses to eliminated choices. If no Condorcet Winner remove the choice with the lowest Top Count, repeating the process until there is a winner.

=head2 Option Immediate Loser Elimination

When a choice has less Approval than the Top Count for the current Top Count Leader, that choice will always lose in pairing and be eliminated first in IRV elimination.

This option makes a handcount faster by eliminating choices faster.

=head2 Note

The original method specified Random as a Tie Breaker, this has the advantage of making the system fully resolveable, but at the extreme Consistency expense of making it possible to get different results with the same ballots.

Your Election Rules should specifiy a tiebreaker, currently only Eliminate All is available in this libary.

=head2 SmithSet IRV

Identifies the Smith Set and runs IRV on it.

=head2 Criteria

=head3 Simplicity

SmithSet IRV is easy to understand but requires a full matrix and thus is harder to handcount than Benham. An aggressive Floor Rule like TCA (see Floor module) is recommended.

=head3 Later Harm

When there is no Condorcet Winner this method is Later Harm Sufficient. There might be edge cases where IRV's sensitivity to dropping order creates a Later Harm effect, but they should be pretty rare and likely tolerable by all but the strictest later harm supporters. When there is a Condorcet Winner the effect is the normal one for a Condorcet Method.

=head3 Condorcet Criteria

Meets Condorcer Winner, Condorcet Loser, and Smith.

=head3 Consistency

In so far as Benham will always elect a Condorcet Winner if present it is more consistent than IRV, when none is present it shares the consistency weaknesses of IRV.

=cut


no warnings 'experimental';
# use YAML::XS;

use Carp;

sub SmithSetIRV ( $E ) {
  my $matrix = $E->PairMatrix();
  $E->logt( 'SmithSetIRV');
  my $winner = $matrix->CondorcetWinner();;
  if ( $winner) {
    $E->logv( "Condorcet Winner: $winner");
  } else {
    my $Smith = $matrix->SmithSet();
    $E->logv( "Smith Set: " . join( ',', sort( keys $Smith->%* )));
    my $IRV = $E->RunIRV( $Smith );
    $winner = $IRV->{'winner'};
    unless ( $winner ) {
      $winner = "Tied: " . join( ', ', $IRV->{'tied'}->@* );
    }
  }
  return $winner;
}

1;



#FOOTER

=pod

BUG TRACKER

L<https://github.com/brainbuz/Vote-Count/issues>

AUTHOR

John Karr (BRAINBUZ) brainbuz@cpan.org

CONTRIBUTORS

Copyright 2019 by John Karr (BRAINBUZ) brainbuz@cpan.org.

LICENSE

This module is released under the GNU Public License Version 3. See license file for details. For more information on this license visit L<http://fsf.org>.

=cut