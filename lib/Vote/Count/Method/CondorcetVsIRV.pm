use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::Method::CondorcetVsIRV;

use namespace::autoclean;
use Moose;

use Vote::Count;
use Vote::Count::Method::CondorcetIRV;

our $VERSION='0.021';

=head1 NAME

Vote::Count::Method::CondorcetVsIRV

=head1 VERSION 0.021

=cut

# ABSTRACT: Condorcet versus IRV

=pod

=head1 SYNOPSIS

  use Vote::Count::Method::CondorcetVsIRV;

  ...

=head1 Method Common Name: Condorcet vs IRV

Determine if the Condorcet Winner needed votes from the IRV winner, elect the condorcet winner if there was not a later harm violation, elect the IRV winner if there was.

The methods looks for a Condorcet Winner, if there is none it uses IRV to find the winner. If there is a Condorcet Winner it uses standard IRV to find the IRV winner. It then copies the ballots and redacts the later choice from those ballots that indicated both. It then determines if one of the two choices is a Condorcet Winner, if not it determines if one of them would win IRV. If either choice is the winner with redacted ballots, they win. If neither wins, the Condorcet Winner dependended on a Later Harm effect against the IRV winner, and the IRV Winner is elected.

The relaxed later harm option, when neither choice wins the redacted ballots, takes the greatest loss by the Condorcet Winner in the redacted matrix and compares it to their margin of victory over the IRV winner. If the victory margin is greater the Condorcet Winner is elected.

=head2 Implementation

CondorcetVsIRV applies the TCA Floor Rule.

An important implementation detail is that CondorcetVsIRV uses Smith Set IRV where possible. The initial election for a Condorcet Winner uses this, providing the IRV Winner should there be no Condorcet Winner. If there is a Condorcet Winner, the Redaction election uses Smith Set IRV. The only time it isn't used is conducting IRV after finding a Condorcet Winner in the initial test.

It was chosen to use the TCA (Top Count vs Approval) Floor Rule because it cannot eliminate any 'Winable Alternatives' (by either Condorcet or IRV), but it is aggressive at eliminating non-winable alternatives which should improve the Consistency of IRV.

Smith Set IRV is used whenever possible because it also eliminates non-winable alternatives from IRV, and it is already alternating between Condorcet and IRV.

The tie breaker is defaulted to (modified) Grand Junction for resolvability.

=head2 Function Name: CondorcetVsIRV

CondorcetVsIRV is exported.



=head2 Criteria

=head3 Simplicity

SmithSet IRV is easy to understand but requires a full matrix and thus is harder to handcount than Benham. An aggressive Floor Rule like TCA (see Floor module) is recommended. If it is desired to Hand Count, a more aggressive Floor Rule would be required, like 15% of First Choice votes. 15% First Choice limits to 6 choices, but 6 choices still require 15 pairings to complete the Matrix.

=head3 Later Harm

When there is no Condorcet Winner this method is Later Harm Sufficient. There might be edge cases where IRV's sensitivity to dropping order creates a Later Harm effect, but they should be pretty rare. When there is a Condorcet Winner the effect is the normal one for a Condorcet Method.

The easiest way to imagine a case where a choice not in the Smith Set changed the outcome is by cloning the winner, such that there is a choice defeating them in early Top Count but not defeating them. The negative impact of the clone is an established weakness of IRV. It would appear that any possible Later Harm issue in addition to be very much at the edge is more than offset by consistency improvement.

Smith Set IRV still has a significant Later Harm failure, but it has demonstrably less Later Harm effect than other Condorcet methods.

=head3 Condorcet Criteria

Meets Condorcer Winner, Condorcet Loser, and Smith.

=head3 Consistency

By meeting the three Condorcet Criteria a level of consistency is guaranteed. When there is no Condorcet Winner the resolution has all of the weaknesses of IRV, as discussed in the Later Harm topic above restricting IRV to the Smith Set would appear to provide a consistency gain over basic IRV.

Smith Set IRV is therefore substantially more consistent than basic IRV, but less consistent than Condorcet methods like SSD that focus on Consistency.

=cut



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
