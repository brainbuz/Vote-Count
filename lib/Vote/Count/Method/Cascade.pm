use strict;
use warnings;
use 5.022;

package Vote::Count::Method::Cascade;
use namespace::autoclean;
use Moose;
extends 'Vote::Count::Charge::Cascade';

no warnings 'experimental';
use feature qw /postderef signatures/;


use Vote::Count::Charge::Utility 'FullCascadeCharge', 'NthApproval';
use Storable 3.15 'dclone';
use Mojo::Template;
use Sort::Hash;
use Data::Dumper;
use Try::Tiny;
use Carp;

our $VERSION = '1.10';

=head1 NAME

Vote::Count::Method::Cascade

=head1 VERSION 1.10

=cut

# ABSTRACT: A Proposal of a Complete Method using Full Cascade Vote Charging.

=pod

=head1 SYNOPSIS
....
=head1 Description

Implements Weighted Improved Gregory Single Transferable Vote based on Scotland's rules.

=head1 WIGRun

Run and log the Election.

=head2 Implementation Notes

.
=head1 Experimental

Small discrepencies with the stages data available for testing have been seen, which are likely to be rounding issues. Until further review can be taken, this code should be considered a preview.

=head1 The Rules

=cut

has 'TieBreakMethod' => (
  is      => 'ro',
  isa     => 'Str',
  init_arg => undef,
  default => 'grandjunction',
);

sub StartElection ( $I ) {
  my @defeated = $I->DefeatLosers( $I->TieBreakMethod, NthApproval( $I ));
  if (@defeated) {
    $I->logv( "Sure Loser Rule Defeated: " . join( ', ', @defeated ));
    $I->logv( $I->TopCount()->RankTableWeighted( $I->VoteValue) );
    $I->TopCount; # need to make sure stats are fresh after defeats.
    my $abandon = $I->CountAbandoned()->{'count_abandoned'};
    $I->logt( "$abandon Ballots are Non-Continuing") if $abandon;
  } else {
    $I->logt( 'No Choices Defeated by Sure Loser at start');
  }
  my $cast = $I->VotesCast();
  my $remain = $cast - $I->CountAbandoned()->{'count_abandoned'};
  $I->logv( "Total Votes Cast: $cast. Active Votes: $remain" )
}

sub _electquotaround ( $I, $quota, @elected ) {
  my $round = $I->Round();
  my $charge = $I->CalcCharge( $quota );
  my $value = FullCascadeCharge( $I->GetBallots, $quota, $charge, $I->GetActive, $I->VoteValue );
  $I->{'roundstatus'}{ $round } = {
    'charge' => $charge,
    'quota'  => $quota,
    'elect'  => \@elected,
    'votes'  => $value,
    'action' => 'elect',
  };
  $I->{lastcharge} = $charge;
  return $quota;
}

sub _noelectquotaround ( $I, $quota, $restype, @defeated ) {
  my $round = $I->Round();
  $I->{'roundstatus'}{ $round } = {
    'charge' => {},
    'quota'  => $quota,
    'action' => $restype,
    $restype  => \@defeated,
  };
}

sub _quotaroundstart ( $I ) {
  my $round = ++$I->{'currentround'};
  my $tc = $I->TCStats();
  my $quota = $I->SetQuota();
  my $cnt_open = scalar $I->SeatsOpen();
  return 0 unless $cnt_open; # election is complete.
  # GetActiveList does not want to be evaluated as a list for counting
  # = () = forces evaluation as a list forced to scalar context.
  my $cnt_active = () = $I->GetActiveList();
  my $cnt_elected = () = $I->Elected();
  if ( $cnt_active <= $cnt_open ) {
    $I->logv( "$cnt_active hopeful choices is not greater than $cnt_open remaining seats.");
    return 0;
  }
  $I->logt( "# Round: $round\n");
  $I->logt( "Quota Set At: $quota  Active Vote Value: $tc->{active_vote_value}\n");
  $I->logv( "Non Continuing Vote Value: $tc->{abandoned}{value_abandoned}\n")
    if  $tc->{abandoned}{value_abandoned};
  $I->logv( "## Round $round Votes\n" . $tc->RankTableWeighted( $I->VoteValue) ."\n" );
  return $quota;
}

sub _dodrop ( $I, $droptype) {
  my $rt = undef;
  if ($droptype eq 'approval' ) {
    $rt = $I->Approval;
    my $round = $I->Round;
    $I->logv( "## Weighted Approval Round $round.\n");
    $I->logv( $rt->RankTableWeighted( $I->VoteValue) );
  } else {
    $rt = $I->TopCount();
  }
  my @losing = $rt->ArrayBottom->@*;
  my ($suspend) = @losing == 1 ? $losing[0] :
      $I->TieBreaker(
                    $I->TieBreakMethod,
                    $I->Active,
                     );
  return $suspend;
}

# Return Value true = continue, false = end quota.
sub ConductQuotaRound ( $I, $droptype='approval' ) {
  my $quota = _quotaroundstart ( $I );
  # false return val from _quotaroundstart inidcates no open seats.
  return 0 unless $quota;
  my $round = $I->Round();
  my @elected = $I->QuotaElectDo( $quota );
  if ( @elected ) {
    $I->logt( "Electing: " . join( ', ', @elected));
    return _electquotaround ( $I, $quota, @elected );
  } else {
    $I->logt( "No choices elected in round $round.");
  }
  my @defeated = $I->DefeatLosers( $I->TieBreakMethod, NthApproval( $I ));
  if (@defeated) {
    $I->logt( "Sure Loser Rule Defeated: " . join( ', ', @defeated ));
    return _noelectquotaround ( $I, $quota, 'defeat', @defeated );
  }
  my $suspend = _dodrop( $I, $droptype);
  $I->logt( "Suspend Lowest by Weighted Approval: $suspend");
  $I->Suspend( $suspend );
  _noelectquotaround ( $I, $quota, 'suspend', $suspend );
  # No active choices ends the Quota phase.
  my $cntactive = () =   $I->GetActiveList;
  unless( $cntactive ) { return 0 }
  else { return $quota }
}
#
    # if( $I->Suspended ) {
    #   $I-logt(
    #       'Reinstating Suspended Choices: ' .
    #       join (',', $I->Reinstate() ));
    # }

__PACKAGE__->meta->make_immutable;
1;

=pod
