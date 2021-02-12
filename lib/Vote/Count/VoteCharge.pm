use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::VoteCharge;
use namespace::autoclean;
use Moose;
extends 'Vote::Count';

no warnings 'experimental::signatures';

use Sort::Hash;
use Data::Dumper;
use Time::Piece;
use Path::Tiny;
use Carp;
use JSON::MaybeXS;
use YAML::XS;
# use Storable 3.15 'dclone';

our $VERSION = '1.10';

has 'Seats' => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
);

# $choice_status->{'choice'} = {
#   key : 'NAME',
#   state => elected, pending, defeated, withdrawn, active, suspended
#   eliminated covers both the withdrawn and defeated states of STV rules.
#   for rules that remove and return choices the suspended status
#   distinguishes from defeated (won't return).
#   votes => 0,
# }
my @choice_valid_states = qw( elected pending defeated withdrawn active suspended );

sub _init_choice_status ( $I ) {
  $I->{'choice_status'} = {};
  $I->{'pending'} = [];
  $I->{'elected'} = [];
  $I->{'suspended'} = [];
  $I->{'stvlog'} = [];
  $I->{'stvround'} = 0;
  for my $c ( $I->GetChoices() ) {
    $I->{'choice_status'}->{$c} = {
      state => 'hopeful',
      votes => 0,
    };
  }
}

# must deal with setting status after floor rule.
sub VoteChargeFloor ( $I ) {

}

# Default tie breaking to GrandJunction,
# Force Precedence as fallback, and generate reproducable precedence
# file if one isn't provided.
sub _setTieBreaks ( $I ) {
  no warnings 'uninitialized';
  unless ( $I->TieBreakMethod() ) {
    $I->logv('TieBreakMethod is undefined, setting to grandjunction');
    $I->TieBreakMethod('grandjunction');
  }
  if ( $I->TieBreakMethod ne 'precedence' ) {
    $I->logv( 'Ties will be broken by: '
        . $I->TieBreakMethod
        . ' with a fallback of precedence' );
    $I->TieBreakerFallBackPrecedence(1);
  }
  unless ( stat $I->PrecedenceFile ) {
    my @order = $I->CreatePrecedenceRandom('/tmp/precedence.txt');
    $I->PrecedenceFile('/tmp/precedence.txt');
    $I->logv( "Order for Random Tie Breakers is: \n" . join( "\n", @order ) );
  }
}

sub ResetVoteValue ($I) {
  my $ballots = $I->GetBallots();
  for my $b ( keys $ballots->%* ) {
    $ballots->{$b}->{'votevalue'} = $I->VoteValue();
    $ballots->{$b}->{'topchoice'} = undef;
  }
}

sub BUILD {
  my $self = shift;
  unless( $self->BallotSetType() eq 'rcv') {
    croak "VoteCharge only supports rcv Ballot Type";
  }
  $self->_setTieBreaks();
  $self->ResetVoteValue();
  $self->_init_choice_status();

}

=pod

CountAbandoned
Counts the value of ballots where the TopChoice from the last Top Count was 'NONE'.

=cut

sub CountAbandoned ( $I ) {
  my $set = $I->GetBallots();
  my $cnt_abandoned = 0;
  my $val_abandoned = 0;
  for my $k ( keys $set->%*) {
    if( $set->{$k}{'topchoice'} eq 'NONE') {
      $cnt_abandoned += $set->{$k}{'count'};
      $val_abandoned += $set->{$k}{'count'} * $set->{$k}{'votevalue'};
    }
  }
  return {  count_abandoned => $cnt_abandoned,
            value_abandoned => $val_abandoned,
            message =>
            "Votes with no Choice: $cnt_abandoned, Value: $val_abandoned" };
}

sub GetChoiceStatus ( $I, $choice = 0 ) {
  if ( $choice ) { return  $I->{'choice_status'}{$choice} }
  else { return $I->{'choice_status'} }
}

sub SetChoiceStatus ( $I, $choice, $status ) {
  if ( $status->{'state'}) {
    unless (grep (/^$status->{'state'}$/, @choice_valid_states )) {
      croak "invalid state *$status->{'state'}* assigned to choice $choice";
    }
    $I->{'choice_status'}->{$choice}{'state'} = $status->{'state'};
  }
  if ( $status->{'votes'}) {
    $I->{'choice_status'}->{$choice}{'votes'} = int $status->{'votes'};
  }
}

sub VCUpdateActive ($I){
  my $active = {};
  for  my $k ( keys $I->GetChoiceStatus()->%* ) {
    $active->{$k} = 1 if $I->{'choice_status'}->{$k}{'state'} eq 'hopeful';
    $active->{$k} = 1 if $I->{'choice_status'}->{$k}{'state'} eq 'pending';
  }
  $I->SetActive( $active );
}

sub Elect( $I, $choice ) {
  delete $I->{'Active'}{$choice};
  $I->{'choice_status'}->{$choice}{'state'} = 'elected';
  $I->{'pending'} = [grep ( !/^$choice$/, $I->{'pending'}->@* )];
  push $I->{'elected'}->@*, $choice;
  return $I->{'elected'}->@*;
}

sub Elected ($I) { return $I->{'elected'}->@* }

sub Defeat( $I, $choice ) {
  delete $I->{'Active'}{$choice};
  $I->{'choice_status'}->{$choice}{'state'} = 'defeated';
}

sub Withdraw( $I, $choice ) {
  delete $I->{'Active'}{$choice};
  $I->{'choice_status'}->{$choice}{'state'} = 'withdrawn';
}

sub Suspend( $I, $choice ) {
  delete $I->{'Active'}{$choice};
  $I->{'choice_status'}->{$choice}{'state'} = 'suspended';
  unless ( grep ( /^$choice$/, $I->{'suspended'}->@* ) ) { push $I->{'suspended'}->@*, $choice }
  return $I->Suspended();
}

sub Suspended ($I ) {
  return $I->{'suspended'}->@*;
}

sub Pending( $I, @choices ) {
PENDINGLOOP:
  for my $choice ( @choices ) {
    next PENDINGLOOP if grep ( /^$choice$/, $I->{'pending'}->@* );
    $I->{'choice_status'}->{$choice}{'state'} = 'pending';
    push $I->{'pending'}->@*, $choice;
    delete $I->{'Active'}{$choice};
  }
  return $I->{'pending'}->@*;
}

sub Reinstate( $I, @choices ) {
  # if no choices are given reinstate all.
  @choices = $I->{'suspended'}->@* unless @choices;
  for my $choice ( @choices ) {
    next unless $I->{'choice_status'}->{$choice}{'state'} eq 'suspended';
    $I->{'suspended'}->@* = grep ( !/^$choice$/,  $I->{'suspended'}->@* );
    $I->{'choice_status'}->{$choice}{'state'} = 'hopeful';
    $I->{'Active'}{$choice} = 1;
  }
}

# need to add a method to synchronize choicestatus -> activeset.

# refund should be here but may have different rules in the methods.
# sub Refund ( $I, $args ) {
#   my $choice = $args->{'choice'};
#   my $surplus = $args->{'surplus'} || 0 ;
#   my $refund =

# }

sub Charge ( $I, $choice, $quota, $charge=$I->VoteValue() ) {
  my $charged = 0;
  my $surplus = 0;
  my @ballotschrgd = ();
  my $cntchrgd = 0;
  my $active = $I->Active();
  my $ballots = $I->BallotSet()->{'ballots'};
# warn Dumper $ballots;
CHARGECHECKBALLOTS:
  for my $B ( keys $ballots->%* ) {
    next CHARGECHECKBALLOTS if ( $I->TopChoice( $B ) ne $choice );
    my $ballot = $ballots->{$B};
    if ( $charge == 0 ) {
      $charged += $ballot->{'votevalue'} * $ballot->{'count'};
      $ballot->{'charged'}{$choice} = $ballot->{'votevalue'};
      $ballot->{'votevalue'} = 0;
    }
    elsif ( $ballot->{'votevalue'} >= $charge ) {
      my $over = $ballot->{'votevalue'} - $charge;
      $charged += ( $ballot->{'votevalue'} - $over ) * $ballot->{'count'};
      $ballot->{'votevalue'} -= $charge ;
      $ballot->{'charged'}{$choice} = $charge;
    } else {
      $charged += $ballot->{'votevalue'} * $ballot->{'count'};
      $ballot->{'charged'}{$choice} = $ballot->{'votevalue'};
      $ballot->{'votevalue'} = 0;
    }
    push @ballotschrgd, $B;
    $cntchrgd += $ballot->{'count'};
  }
  $I->{'choice_status'}->{$choice}{'votes'} += $charged;
  $surplus = $I->{'choice_status'}->{$choice}{'votes'} - $quota;
# # warn Dumper $ballots;
#   croak
#     "undercharge error $choice surplus $surplus charge $charge is too low.\n"
#     if $surplus < 0 && $charge > 0 ;
  $I->{'choice_status'}->{$choice}{'votes'} = $charged;
  return (
      { choice => $choice, surplus => $surplus, ballotschrgd => \@ballotschrgd,
      cntchrgd => $cntchrgd, quota => $quota });
}

sub STVEvent( $I, $data=0 ) {
  return $I->{'stvlog'} unless $data;
  push $I->{'stvlog'}->@*, $data;
}

sub WriteSTVEvent( $I) {
  my $jsonpath = $I->LogTo . '_stvevents.json';
  my $yamlpath = $I->LogTo . '_stvevents.yaml';
  # my $yaml = ;
  my $coder = JSON->new->ascii->pretty;
  path($jsonpath)->spew( $coder->encode($I->STVEvent()) );
  path($yamlpath)->spew( Dump $I->STVEvent() );
}

sub STVRound($I) { return $I->{'stvround'} }

sub NextSTVRound( $I) { return ++$I->{'stvround'} }

# keep this scrap for a future reporting method.
# used when debugging the rounding diff between mollison's scotland results
# and votecount's.
# my $status_table = '';
# my %top = $C->TopCount()->RawCount()->%*;
# my $vv = $C->VoteValue();
# my %status = ();
# while ( my ( $k, $v ) = each ($C->GetChoiceStatus()->%* ) ) {
#   if ( $v->{votes} > 0 ) { $status{$k} = $v->{votes} / $vv }
#   else {
#     $status{$k} = $top{$k} / $vv;
#   }
# }
# note( Dumper \%status );
# my $activotes = 0;
# map { $activotes += $_ } ( values %status );
# # must use tempvar hash would change during map.
# $status{'ActiveVotes'} = $activotes ;
# note("status -- $status{'ActiveVotes'}" );
# $status{'TotalVotes'} = $C->{BallotSet}{votescast};
# $status{'NONE'} = $C->Discontinued()->{transfervalue} / $vv;
# $status{'RoundingDiff'} = $status{'TotalVotes'} - ( $activotes  );
# note( Dumper \%status );
# #note( Dumper %top );


=head1 NAME

Vote::Count::Method::VoteCharge

=head1 VERSION 1.10

=cut

# ABSTRACT: Experiment with the Vote::Charge implementation of STV.

=pod

=head1 SYNOPSIS

  my $E = Vote::Count::VoteCharge->new(
    Seats => 3,
    VoteValue => 1000,
    BallotSet => read_ballots('t/data/data1.txt', ) );

  $E->Elect('SOMECHOICE');
  $E->Charge('SOMECHOICE', $quota, $pervotecharge );
  say E->GetChoiceStatus( 'CARAMEL'),
   >  { state => 'withdrawn', votes => 0 }

=head1 Vote Charge implementation of Surplus Transfer

Vote Charge is how Vote::Count implements Surplus Transfer. The wording is chosen to make the concept more accessible to a general audience. It also uses integer math and imposes truncation as the rounding rule.

Vote Charge describes the process of Single Transferable Vote as:

The Votes are assigned a value, based on the number of seats and the total value of all of the votes, a cost is determined for electing a choice. The votes supporting that choice are then charged to pay that cost. The remainder of the value for the vote, if any, is available for the next highest choice of the vote.

When value is transferred back to the vote, Vote Charge refers to it as a Rebate.

Vote Charge uses integer math and truncates all remainders. Setting the Vote Value is equivalent to setting a number of decimal places, a Vote Value of 100,000 is the same as a 5 decimal place precision.

=head1 Description

This module provides methods that can be shared between VoteCharge implementations and does not present a complete tool for conducting STV elections. Look at the Methods that have been implemented as part of Vote::Count.

=head1 Candidate / Choices States

Single Transferable Vote rules have more states than Active, Eliminated and Elected. Not all methods need all of the possible states. The SetChoiceStatus method is not linked to the underlying Vote::Count objects Active Set, the action methods: Elect, Defeat, Suspend, Reinstate, Withdraw do update the Active Set.

=head3 GetChoiceStatus

When called with the argument of a Choice, returns a hashref with the keys 'state' and 'votes'. When called without argument returns a hashref with the Choices as keys, and the values a hashref with the 'state' and 'votes' keys.

=head3 SetChoiceStatus

Takes the arguments of a Choice and a hashref with the keys 'state' and 'votes'. This method does not keep the underlying active list in Sync. Use either the targeted methods such as Suspend and Defeat or use VCUpdateActive to force the update.

=head2 Active is Hopeful

Active choices are referred to as Hopeful.

=head3 VCUpdateActive

Update the ActiveSet of the underlying Vote::Count object to match the set of Choices that are currently 'hopeful' or 'pending'.

=head2 Elected and Pending

In addition to Elected, there is a Pending State. Typically, Pending means a Choice has reached the Quota, but not completed its Charges and Rebates. The distinction is for the benefit of methods that need choices held in pending, both Pending and Elected choices are removed from the active set.

=head3 Elect, Elected

Set Choice as Elected. Elected returns the list of currently elected choices.

=head3 Pending

Takes an optional list of Choices to set as Pending. Returns the list of Pending Choices.

=head2 Eliminated: Withdrawn, Defeated, or Suspended

In methods that set the Quota only once, choices eliminated before setting Quoata are Withdrawn and may result in null ballots that can be exluded. Choices eliminated after setting Quota are Defeated. Some rules bring eliminated Choices back in later Rounds, Suspended distinguishes those eligible to return.

=head3 Defeat, Withdraw, Suspend

Perform the corresponding action for a Choice. Reinstate

  $E->Defeat('MARMALADE');

=head3 Reinstate

Will reinstate all currently suspended choices or may be given a list of suspended choices that will be reinstated.

=head2 STVRound, NextSTVRound

STVRound returns the current Round, NextSTVRound advances the Round Counter and returns the new Round number.

=head2 STVEvent

Takes a reference as argument to add that reference to an Event History. This needs to be done seperately from logx because STVEvent holds a list of data references instead of readably formatted events.

=head2 WriteSTVEvent

Writes JSON and YAML logs (path based on LogTo) of the STVEvents.

=head2 Charge

Charges Ballots for election of choice, parameters are $choice, $quota and $charge (defaults to VoteValue ). The method validates that at least the quota is charged returning an exception when it failes. When an undercharge is permitted either reduce the quota to 0 or set the charge to 0. When the charge is set to 0, the remaining Vote Value from each ballot will be charged and the quota check will be skipped.

=cut

__PACKAGE__->meta->make_immutable;
1;

#FOOTER

=pod

BUG TRACKER

L<https://github.com/brainbuz/Vote-Count/issues>

AUTHOR

John Karr (BRAINBUZ) brainbuz@cpan.org

CONTRIBUTORS

Copyright 2019-2020 by John Karr (BRAINBUZ) brainbuz@cpan.org.

LICENSE

This module is released under the GNU Public License Version 3. See license file for details. For more information on this license visit L<http://fsf.org>.

=cut

