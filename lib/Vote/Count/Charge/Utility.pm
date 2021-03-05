use strict;
use warnings;
use 5.022;

package Vote::Count::Charge::Utility;
no warnings 'experimental';
use feature qw /postderef signatures/;
use Sort::Hash;
use Vote::Count::TextTableTiny qw/generate_table/;

our $VERSION = '1.10';

# ABSTRACT: Non OO Components for the Vote::Charge implementation of STV.

=head1 NAME

Vote::Count::Method::VoteCharge::Utility

=head1 VERSION 1.10

=cut

=pod

=head1 SYNOPSIS

  use Vote::Count::Method::VoteCharge::Utility 'FullCascadeCharge';
  my $charged = FullCascadeCharge(
    $Election->GetBallots(), $quota, $cost, $active, $votevalue );

=head1 FullCascadeCharge

Performs a full Cascading Charge of the Ballots. It takes a list of choices to be elected, with the Vote Value to be charged for each of these. It walks through the Ballots and looks at each choice on the ballot in order. If the choice is elected the vote is charged (up to the remaining vote value) the specified charge and then continues to the next choice on the ballot. If the choice is in the active list (hopeful) it stops processing the choice on the ballot and moves on to the next ballot, otherwise it will continue until the ballot exhausts its choices or vote value.

Parameters are Ballots, Quota, Cost (HashRef of elected choices and the charge to each), Active Set (HashRef), and the VoteValue assigned initially to the Ballots.

Return Value is a HashRef where the keys are the Elected Choices, the values are a HashRef with the keys: value, count, surplus. The value key is the total Vote Value charged for that choice, the count is the number of Ballots which contributed any amount to that charge, and finally the surplus is the amount of value over or under (negative) the quota.

The method is non-OO (thus the need to import it). This permits isolation of values, which may be needed for performing estimations to establish the Costs.

The Ballots are passed as a HashRef and the votevalue will be modified, if you do not want the Ballots modified, provide a copy of them (Storable 'dclone' is recommended)

=head1 NthApproval

Finds the choice that would fill the last seat if the remaining seats were to be filled by highest Top Count, and sets the Vote Value for that Choice as the requirement. All Choices that do not have a weighted Approval greater than that requirement are returned, they will never be elected and are safe to defeat immediately.

=cut

use Exporter::Easy ( OK => [ 'FullCascadeCharge', 'NthApproval', 'WeightedTable', 'ChargeTable' ], );

sub FullCascadeCharge ( $ballots, $quota, $cost, $active, $votevalue ) {
  for my $b ( keys $ballots->%* ) {
    $ballots->{$b}{'votevalue'} = $votevalue;
  }
  my %chargedval =
    map { $_ => { value => 0, count => 0, surplus => 0 } } ( keys $cost->%* );
FullChargeBALLOTLOOP1:
  for my $V ( values $ballots->%* ) {
    unless ( $V->{'votevalue'} > 0 ) { next FullChargeBALLOTLOOP1 }
  FullChargeBALLOTLOOP2:
    for my $C ( $V->{'votes'}->@* ) {
      if ( $active->{$C} ) { last FullChargeBALLOTLOOP2 }
      elsif ( $cost->{$C} ) {
        my $charge = do {
          if   ( $V->{'votevalue'} >= $cost->{$C} ) { $cost->{$C} }
          else                                      { $V->{'votevalue'} }
        };
        $V->{'votevalue'}        -= $charge;
        $chargedval{$C}{'value'} += $charge * $V->{'count'};
        $chargedval{$C}{'count'} += $V->{'count'};
        unless ( $V->{'votevalue'} > 0 ) { last FullChargeBALLOTLOOP2 }
      }
    }
  }
  for my $E ( keys %chargedval ) {
    $chargedval{$E}{'surplus'} = $chargedval{$E}{'value'} - $quota;
  }
  return \%chargedval;
}

# untilist method
# moved to tiebreaker
# add tests where ties in the middle move bottom running.

sub NthApproval ( $I ) {
  my $tc            = $I->TopCount();
  my $ac            = $I->Approval();
  my $seats         = $I->Seats() - $I->Elected();
  my @defeat        = ();
  my $bottomrunning = $tc->HashByRank()->{$seats}[0];
  my $bar           = $tc->RawCount()->{$bottomrunning};
  for my $A ( $I->GetActiveList ) {
    next if $A eq $bottomrunning;
    my $avv = $ac->{'rawcount'}{$A};
    push @defeat, ($A) if $avv <= $bar;
  }
  if (@defeat) {
    my $deflst = join( ', ', @defeat );
    $I->logv( qq/
      Seats: $seats Choice $seats: $bottomrunning ( $bar )

      Choices Not Over $bar by Weighted Approval: $deflst
    /);
  }
  return @defeat;
}

sub ChargeTable ( $estimate, $result ) {
  my @rows = (['Choice','Charge','Value Charged', 'Votes Charged','Surplus'] );
  for my $c ( sort keys $estimate->%* ) {
    push @rows, [
      $c, $estimate->{$c},
      $result->{$c}{'value'},
      $result->{$c}{'count'},
      $result->{$c}{'surplus'}
    ]
  }
  return generate_table(
      rows => \@rows,
      style => 'markdown',
      align => [qw/ l l r r r/]
      ) . "\n";
}

sub WeightedTable ( $I ) {
  my $approval = $I->Approval()->RawCount();
  my $tc = $I->TopCount();
  my $tcr = $tc->RawCount();
  my $vv = $I->VoteValue();
  my %data =();
  my @active = $I->GetActiveList();
  for my $choice ( @active ) {
    $data{ $choice } = {
      'votevalue' => $tcr->{ $choice },
      'votes' => sprintf( "%.2f",$tcr->{ $choice } / $vv),
      'approvalvalue' => $approval->{ $choice },
      'approval' => sprintf( "%.2f", $approval->{ $choice } / $vv),
    };
  }
  my @rows = ( [ 'Rank', 'Choice', 'Votes', 'VoteValue', 'Approval', 'Approval Value' ] );
  my %byrank = $tc->HashByRank()->%*;
  for my $r ( sort { $a <=> $b } ( keys %byrank ) ) {
    my @choice = sort $byrank{$r}->@*;
    for my $choice (@choice) {
      # my $votes = $tcr->{$choice};
      my $D = $data{$choice};
      my @row = (
          $r, $choice, $D->{'votes'}, $D->{'votevalue'},
          $D->{'approval'}, $D->{'approvalvalue'} );
      push @rows, ( \@row );
    }
  }
  return generate_table(
    rows => \@rows,
    style => 'markdown',
    align => [qw/ l l r r r r/]
    ) . "\n";
}
1;
