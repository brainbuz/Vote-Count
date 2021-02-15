use strict;
use warnings;
use 5.022;

package Vote::Count::VoteCharge::Utility;
no warnings 'experimental';
use feature qw /postderef signatures/;

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

=cut

use Exporter::Easy ( OK =>
    ['FullCascadeCharge'],
);

sub FullCascadeCharge ( $ballots, $quota, $cost, $active, $votevalue ) {
  for my $b ( keys $ballots->%* ) {
    $ballots->{$b}{'votevalue'} = $votevalue; }
  my %chargedval = map { $_ => { value => 0, count => 0, surplus => 0 } } ( keys $cost->%* );
FullChargeBALLOTLOOP1:
  for my $V ( values $ballots->%* ) {
    unless ( $V->{'votevalue'} > 0 ) { next FullChargeBALLOTLOOP1 }
FullChargeBALLOTLOOP2:
    for my $C ( $V->{'votes'}->@* ) {
      if ( $active->{$C} ) { last FullChargeBALLOTLOOP2 }
      elsif ( $cost->{$C} ) {
        my $charge = do {
            if ( $V->{'votevalue'} >= $cost->{$C} ) { $cost->{$C} }
            else { $V->{'votevalue'} }
          };
        $V->{'votevalue'} -= $charge;
        $chargedval{$C}{'value'} += $charge * $V->{'count'};
        $chargedval{$C}{'count'} += $V->{'count'};
        unless ( $V->{'votevalue'} > 0 ) { last FullChargeBALLOTLOOP2 }
      }
    }
  }
  for my $E ( keys %chargedval ) {
    $chargedval{$E}{'surplus'} = $chargedval{$E}{'value'} - $quota ;
  }
  return \%chargedval;
}

1;