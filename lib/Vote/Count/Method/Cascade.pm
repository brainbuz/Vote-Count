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
use Sort::Hash;
use Data::Dumper;
use Try::Tiny;
use Path::Tiny;
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

has 'AutomaticDefeat' => (
  is      => 'ro',
  isa     => 'Str',
  default => 'NthApproval',
);

has 'CalculatedPrecedenceFile' => (
  is      => 'ro',
  isa     => 'Str',
  default => '/tmp/vote_count_method_charge_precedence.txt',
);

has 'FloorRule' => (
  is       => 'rw',
  isa      => 'Str',
  default  => 'Approval',
);

has 'FloorThresshold' => (
  is      => 'ro',
  isa     => 'Num',
  default => 1,
  );

sub StartElection ( $Election ) {
  $Election->STVFloor();
  my @precedence = ();
  if ($Election->TieBreakMethod() eq 'Precedence') {
    @precedence =  path( $Election->PrecedenceFile() )->lines({ chomp => 1 });
  } else {
    @precedence = $Election->UntieActive('TopCount', 'Approval')->OrderedList;
    path( $Election->CalculatedPrecedenceFile
      )->spew( map { "$_\n" } (@precedence));
    $Election->PrecedenceFile( $Election->CalculatedPrecedenceFile );
    $Election->TieBreakMethod('Precedence');
  }
  my $prec = 0;
  $Election->logv( qq/## Tie Breaker Precedence from Top Count, Approval, FallBack:/,
    map { "${\ ++$prec }. $_" } @precedence );
  # my @defeated = NthApproval( $I );
  # if (@defeated) {
  #   $I->logt( "Automatic Rule Defeated: " . join( ', ', @defeated ));
  #   for (@defeated) { $I->Defeat($_)}
  #   $I->logv( $I->TopCount()->RankTableWeighted( $I->VoteValue) );
  #   my $abandon = $I->CountAbandoned()->{'count_abandoned'};
  #   $I->logv( "$abandon Ballots are Non-Continuing") if $abandon;
  # } else {
  #   $I->logt( 'No Choices Defeated by Sure Loser at start');
  # }
  # my $cast = $I->VotesCast();
  # my $remain = $cast - $I->CountAbandoned()->{'count_abandoned'};
  # $I->logv( "Total Votes Cast: $cast. Active Votes: $remain" )
}

sub _electround ( $I, $quota, @elected ) {
  my $round  = $I->Round();
  my $charge = $I->CalcCharge($quota);
  my $value =
    FullCascadeCharge( $I->GetBallots, $quota, $charge, $I->GetActive,
    $I->VoteValue );
  $I->{'roundstatus'}{$round} = {
    'charge' => $charge,
    'quota'  => $quota,
    'elect'  => \@elected,
    'votes'  => $value,
    'action' => 'elect',
  };
  $I->{lastcharge} = $charge;
  return $quota;
}

sub _noelectround ( $I, $quota, $restype, @defeated ) {
  my $round = $I->Round();
  $I->{'roundstatus'}{$round} = {
    'charge' => {},
    'quota'  => $quota,
    'action' => $restype,
    $restype => \@defeated,
  };
}

sub _roundstart ( $I ) {
  my $round    = ++$I->{'currentround'};
  my $tc       = $I->TCStats();
  my $quota    = $I->SetQuota();
  my $cnt_open = scalar $I->SeatsOpen();
  return 0 unless $cnt_open;    # election is complete.
      # GetActiveList does not want to be evaluated as a list for counting
      # = () = forces evaluation as a list forced to scalar context.
  my $cnt_active  = () = $I->GetActiveList();
  my $cnt_elected = () = $I->Elected();

  if ( $cnt_active <= $cnt_open ) {
    $I->logv(
"$cnt_active hopeful choices is not greater than $cnt_open remaining seats."
    );
    return 0;
  }
  $I->logt("# Round: $round\n");
  $I->logt(
    "Quota Set At: $quota  Active Vote Value: $tc->{active_vote_value}\n");
  $I->logv("Non Continuing Vote Value: $tc->{abandoned}{value_abandoned}\n")
    if $tc->{abandoned}{value_abandoned};
  $I->logv( "## Round $round Votes\n"
      . $tc->RankTableWeighted( $I->VoteValue )
      . "\n" );
  return $quota;
}

sub _dodrop ( $I, $droptype ) {
  my $rt       = undef;
  my $desctype = 'Weighted Approval';
  if ( $droptype eq 'approval' ) {
    $rt = $I->Approval;
    my $round = $I->Round;
    $I->logv("## Weighted Approval Round $round.\n");
    $I->logv( $rt->RankTableWeighted( $I->VoteValue ) );
    # elsif for bottom runoff.
  }
  else {
    $rt       = $I->TopCount();
    $desctype = 'Top Count';
  }
  my @losing = $rt->ArrayBottom->@*;
  my ($suspend) =
      @losing == 1
    ? $losing[0]
    : $I->TieBreaker( $I->TieBreakMethod, $I->Active, );
  $I->logt("Suspend Lowest by $desctype: $suspend");
  return $suspend;
}

# Return Value true = continue, false = end quota.
sub ConductRound ( $I, $droptype = 'approval' ) {

  # Check Complete
  # Automatic Defeat
  # Check Complete
  # Quota
  # Elect
  # Check for Finale
  # Drop Rule

  my $quota = _roundstart($I);
  # false return val from _roundstart inidcates no open seats.
  return 0 unless $quota;
  my $round   = $I->Round();
  my @elected = $I->QuotaElectDo($quota);
  if (@elected) {
    $I->logt( "Electing: " . join( ', ', @elected ) );
    return _electround( $I, $quota, @elected );
  }
  else {
    $I->logt("No choices elected in round $round.");
  }
  my @defeated = $I->TieBreakMethod, NthApproval($I);
  if (@defeated) {
    for (@defeated) { $I->Defeat($_) }
    $I->logt( "Sure Loser Rule Defeated: " . join( ', ', @defeated ) );
    return _noelectround( $I, $quota, 'defeat', @defeated );
  }
  my $suspend = _dodrop( $I, $droptype );
  $I->Suspend($suspend);
  _noelectround( $I, $quota, 'suspend', $suspend );
  # No active choices ends the Quota phase.
  my $cntactive = () = $I->GetActiveList;
  unless ($cntactive) { return 0 }
  else                { return $quota }
}

# sub CascadeRound

# sub WIGRun ( $I ) {
#   my $pre_rslt = $I->_WIGStart();
#   my $quota    = $pre_rslt->{'quota'};
#   my $seats    = $I->Seats();

# WIGDOROUNDLOOP:
#   while ( $I->Elected() < $seats ) {
#     my $rnd = $I->_WIGRound($quota);
#     last WIGDOROUNDLOOP if _wigcomplete ( $I, $rnd );
#     my @pending = $rnd->{'pending'}->@*;
#     if ( scalar(@pending)){
#       for my $pending (@pending) {
#         my $chrg = $I->Charge( $pending, $quota );
#         $I->_WIGElect($chrg);
#         }
#     } else {
#       $I->logv( "Eliminating low choice: $rnd->{'lowest'}\n");
#       $I->Defeat($rnd->{'lowest'});
#       last WIGDOROUNDLOOP if _wigcomplete ( $I, $rnd );
#     }
#   }
#   my @elected = $I->Elected();
#   $I->STVEvent( { winners => \@elected });
#   $I->logt( "Winners: " . join( ', ', @elected ));
# }

# sub _WIGRound ( $I, $quota ) {
#   my $round_num = $I->NextSTVRound();
#   my $round     = $I->TopCount();
#   my $roundcnt  = $round->RawCount();
#   my @choices   = $I->GetActiveList();
#   my %rndvotes  = ();
#   my $leader = $round->Leader()->{'winner'};
#   my $votes4leader = $round->RawCount->{$leader};
#   my $pending = $votes4leader >= $quota ? $leader : '';

#   for my $C (@choices ) {
#     if( $roundcnt->{ $C} >= $quota ) {
#       $rndvotes{ $C } = $roundcnt->{ $C } ;
#     }
#   }
#   my @pending = sort_hash( \%rndvotes, 'numeric', 'desc' );

#   my $rslt = {
#     pending  => \@pending,
#     winvotes => \%rndvotes,
#     quota    => $quota,
#     round    => $round_num,
#     allvotes => $round->RawCount(),
#     lowest   => $round->ArrayBottom()->[0],
#     noncontinuing => $I->CountAbandoned()->{'value_abandoned'},
#   };
#   $I->STVEvent($rslt);
#   $I->logv( _format_round_result( $rslt, $round, $I->VoteValue() ) );
#   return ($rslt);
# }

__PACKAGE__->meta->make_immutable;
1;

=pod

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

