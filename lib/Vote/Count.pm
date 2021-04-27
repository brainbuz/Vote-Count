use strict;
use warnings;
use 5.024;
use feature qw /postderef signatures/;

# ABSTRACT: Toolkit for implementing voting methods.

package Vote::Count;
use namespace::autoclean;
use Moose;

use Data::Dumper;
use Time::Piece;
use Path::Tiny;
use Vote::Count::Matrix;
# use Storable 3.15 'dclone';

no warnings 'experimental';

our $VERSION='1.212';

=head1 NAME

Vote::Count

=head1 VERSION 1.212

=head2 A Toolkit for determining the outcome of Preferential Ballots.

Vote::Count a Toolkit for implementing multiple voting systems, allowing a wide range of method options. Vote::Count provides a lot of options to facilitate writing code to match your election rules.

=head1 DOCUMENTATION

=head2 L<COMMON|Vote::Count::Common>

The core methods of Vote::Count are documented in this Module.

=head2 L<OVERVIEW|Overview>

An overview of Preferential Voting and introduction to Vote::Count.

=head2 L<CATALOG|Catalog>

Catalog of Preferential Voting Methods implemented by Vote::Count and the Modules providing them.

=head2 L<MULTIMEMBER|MultiMember>

Overview of Preferential Ballots for Multi-Member Elections and their implementation in Vote::Count.

=cut

has 'PairMatrix' => (
  is      => 'ro',
  isa     => 'Object',
  lazy    => 1,
  builder => '_buildmatrix',
);

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

#INDEXSECTION

=pod

=head1 INDEX of Vote::Count Modules and Documentation

=over

=item *

L<Vote::Count>

=item *

L<Vote::Count::Approval>

=item *

L<Vote::Count::Borda>

=item *

L<Vote::Count::BottomRunOff>

=item *

L<Vote::Count::Catalog>

=item *

L<Vote::Count::Charge>

=item *

L<Vote::Count::Charge::Cascade>

=item *

L<Vote::Count::Common>

=item *

L<Vote::Count::Floor>

=item *

L<Vote::Count::Helper>

=item *

L<Vote::Count::Helper::FullCascadeCharge>

=item *

L<Vote::Count::Helper::NthApproval>

=item *

L<Vote::Count::Helper::Table>

=item *

L<Vote::Count::Helper::TestBalance;>

=item *

L<Vote::Count::IRV>

=item *

L<Vote::Count::Log>

=item *

L<Vote::Count::Matrix>

=item *

L<Vote::Count::Method::Cascade>

=item *

L<Vote::Count::Method::CondorcetDropping>

=item *

L<Vote::Count::Method::CondorcetIRV>

=item *

L<Vote::Count::Method::CondorcetVsIRV>

=item *

L<Vote::Count::Method::MinMax>

=item *

L<Vote::Count::Method::STAR>

=item *

L<Vote::Count::Method::WIGM>

=item *

L<Vote::Count::MultiMember>

=item *

L<Vote::Count::Overview>

=item *

L<Vote::Count::Range>

=item *

L<Vote::Count::RankCount>

=item *

L<Vote::Count::ReadBallots>

=item *

L<Vote::Count::Redact>

=item *

L<Vote::Count::Score>

=item *

L<Vote::Count::Start>

=item *

L<Vote::Count::TextTableTiny>

=item *

L<Vote::Count::TieBreaker>

=item *

L<Vote::Count::TopCount>

=back

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

SUPPORT

This software is provided as is, per the terms of the GNU Public License. Professional Support, Validation and Customization services are available, please contact the Author for a quote.

=cut

