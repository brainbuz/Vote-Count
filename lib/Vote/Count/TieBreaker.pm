use strict;
use warnings;
use 5.022;

use feature qw /postderef signatures/;

package Vote::Count::TieBreaker;
use Moose::Role;

no warnings 'experimental';
use List::Util qw( min max sum );
use Path::Tiny;
# use Data::Dumper;

our $VERSION='1.07';

=head1 NAME

Vote::Count::TieBreaker

=head1 VERSION 1.07

=head1 Synopsis

  my $Election = Vote::Count->new(
    BallotSet      => $ballotsirvtie2,
    TieBreakMethod => 'approval'
  );

=cut

# ABSTRACT: TieBreaker object for Vote::Count. Toolkit for vote counting.

=head1 Tie Breakers

The most important thing for a Tie Breaker to do is it should use some reproducible difference in the Ballots to pick a winner from a Tie. The next thing it should do is make sense. Finally, the ideal Tie Breaker will resolve when there is any difference to be found. Arguably the best use of Borda Count is as a Tie Breaker, First Choice votes and Approval are also other great choices.

TieBreakMethod is specified as an argument to Vote::Count->new(). The TieBreaker is called internally from the resolution method via the TieBreaker function, which requires the caller to pass its TieBreakMethod.

=head2 TieBreakMethod argument to Vote::Count->new

  'approval'
  'all'
  'borda' [ applies Borda Count to current Active set ]
  'barda_all' [ applies Borda Count to all of the choices ]
  'grandjunction'
  'precedencefile' [ requires also setting PrecedenceFile]


=head1 Grand Junction

The Grand Junction (also known as Bucklin) method is one of the simplest and easiest to Hand Count RCV resolution methods. Other than that it is generally not considered a good method.

Because it is simple, and always resolves, except when ballots are perfectly matched up, it is a really

=head2 The (Standard) Grand Junction Method

=over

=item 1

Count the Ballots to determine the quota for a majority.

=item 2

Count the first choices and elect a choice which has a majority.

=item 3

If there is no winner add the second choices to the totals and elect the choice which has a majority (or the most votes if more than one choice reaches a majority).

=item 4

Keep adding the next rank to the totals until either there is a winner or all ballots are exhausted.

=item 5

When all ballots are exhausted the choice with the highest total wins.

=back

=head2 As a Tie Breaker

The Tie Breaker Method is modified.

Instead of Majority, any choice with a current total less than another is eliminated. This allows resolution of any number of choices in a tie.

The winner is the last choice remaining.

=head2 TieBreakerGrandJunction

  my $resolve = $Election->TieBreakerGrandJunction( $choice1, $choice2 [ $choice3 ... ]  );
  if ( $resolve->{'winner'}) { say "Tie Winner is $resolve->{'winner'}"}
  elsif ( $resolve->{'tie'}) {
    my @tied = $resolve->{'tied'}->@*;
    say "Still tied between @tied."
  }

The Tie Breaking will be logged to the verbose log, any number of tied choices may be provided.

=cut

sub TieBreakerGrandJunction ( $self, @choices ) {
  my $ballots = $self->BallotSet()->{'ballots'};
  my %current = ( map { $_ => 0 } @choices );
  my $deepest = 0;
  for my $b ( keys $ballots->%* ) {
    my $depth = scalar $ballots->{$b}{'votes'}->@*;
    $deepest = $depth if $depth > $deepest;
  }
  my $round = 1;
  while ( $round <= $deepest ) {
    $self->logv("Tie Breaker Round: $round") if $self->can('logv');
    for my $b ( keys $ballots->%* ) {
      my $pick = $ballots->{$b}{'votes'}[ $round - 1 ] or next;
      if ( defined $current{$pick} ) {
        $current{$pick} += $ballots->{$b}{'count'};
      }
    }
    my $max = max( values %current );
    for my $c ( sort @choices ) {
      $self->logv("\t$c: $current{$c}") if $self->can('logv');
    }
    for my $c ( sort @choices ) {
      if ( $current{$c} < $max ) {
        delete $current{$c};
        $self->logv("Tie Breaker $c eliminated") if $self->can('logv');
      }
    }
    @choices = ( sort keys %current );
    if ( 1 == @choices ) {
      $self->logv("Tie Breaker Won By: $choices[0]") if $self->can('logv');
      return { 'winner' => $choices[0], 'tie' => 0, 'tied' => [] };
    }
    $round++;
  }
  return { 'winner' => 0, 'tie' => 1, 'tied' => \@choices };
}

=head1 Borda-like Later Harm Protected

This method is superficially similar to Borda. However, it only scores the best ranked member of the tie, ignoring the later votes. The tie member with the highest score wins. The original position on the ballot is used to score. It is subject to all of the Borda weighting problems. It is Later Harm Protected (within the tied set), but less resolvable than Modified Grand Junction.

=head2 TieBreakerBordalikeLaterHarm ()

  Currently unimplemented ...

=head1 Method TieBreaker

Implements some basic methods for resolving ties. The default value for IRV is 'all', and the default value for Matrix is 'none'. 'all' is inappropriate for Matrix, and 'none' is inappropriate for IRV.

  my @keep = $self->TieBreaker( $tiebreaker, $active, @choices );

TieBreaker returns a list containing the winner, if the method is 'none' the list is empty, if 'all' the original @choices list is returned. If the TieBreaker is a tie there will be multiple elements.

=head1 Precedence

Since many existing Elections Rules call for Random, and Vote::Count does not accept Random as the result can be different across runs, Precedence allows the Administrators of an election to randomly or arbitrarily determine who will win ties before running Vote::Count.

The Precedence list takes the choices of the election one per line. Choices defeat any choice lower than them in the list. When Precedence is used an additional attribute must be specified for the Precedence List.

 my $Election = Vote::Count->new(
   BallotSet => read_ballots('somefile'),
   TieBreakMethod => 'precedence',
   PrecedenceFile => 'precedencefile');

=cut

sub TieBreakerPrecedence ( $I, @choices ) {
  my %ordered = ();
  my $start = 0;
  for ( split /\n/, path( $I->PrecedenceFile() )->slurp() ) {
    $_ =~ s/\s//g; #strip out any accidental whitespace
    $ordered{ $_ } = $start++ ;
  }
  my $ballots = $I->BallotSet()->{'ballots'};
  my $winner = $choices[0];
  for my $c ( @choices ) {
    unless( defined $ordered{$c} ) { die "Choice $c missing from precedence file\n" }
    if ( $ordered{$c} < $ordered{$winner } ) { $winner = $c }
  }
  return { 'winner' => $winner, 'tie' => 0, 'tied' => [] };
}

sub TieBreaker ( $I, $tiebreaker, $active, @choices ) {
  if ( $tiebreaker eq 'all' )  { return @choices }
  if ( $tiebreaker eq 'none' ) { return () }
  my $choices_hashref = { map { $_ => 1 } @choices };
  my $ranked = undef;
  if ( $tiebreaker eq 'borda' ) {
    $ranked = $I->Borda($active);
  }
  elsif ( $tiebreaker eq 'borda_all' ) {
    $ranked = $I->Borda( $I->BallotSet()->{'choices'} );
  }
  elsif ( $tiebreaker eq 'approval' ) {
    $ranked = $I->Approval($choices_hashref);
  } elsif ( $tiebreaker eq 'topcount') {
      $ranked = $I->TopCount( $choices_hashref );
  }
  elsif ( $tiebreaker eq 'grandjunction' ) {
    my $GJ = $I->TieBreakerGrandJunction(@choices);
    if    ( $GJ->{'winner'} ) { return ( $GJ->{'winner'} ) }
    elsif ( $GJ->{'tie'} )    { return $GJ->{'tied'}->@* }
    else { die "unexpected (or no) result from $tiebreaker!\n" }
  }
  elsif ( $tiebreaker eq 'precedence' ) {
    # The one nice thing about precedence is that there is always a winner.
    return $I->TieBreakerPrecedence( @choices )->{'winner'};
  }
  else { die "undefined tiebreak method $tiebreaker!\n" }
  my @highchoice = ();
  my $highest    = 0;
  my $counted    = $ranked->RawCount();
  for my $c (@choices) {
    if ( $counted->{$c} > $highest ) {
      @highchoice = ($c);
      $highest    = $counted->{$c};
    }
    elsif ( $counted->{$c} == $highest ) {
      push @highchoice, $c;
    }
  }
  my $terse =
      "Tie Breaker $tiebreaker: "
    . join( ', ', @choices )
    . "\nwinner(s): "
    . join( ', ', @highchoice );
  $I->{'last_tiebreaker'} = {
    'terse'   => $terse,
    'verbose' => $ranked->RankTable(),
  };
  return @highchoice;
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
