use strict;
use warnings;
use 5.022;

package Vote::Count::Method::Concept;
use namespace::autoclean;
use Moose;
extends 'Vote::Count::VoteCharge';

no warnings 'experimental';
use feature qw /postderef signatures/;

use Storable 3.15 'dclone';
use Mojo::Template;
use Sort::Hash;
use Data::Dumper;
use Try::Tiny;

our $VERSION = '1.10';

=head1 NAME

Vote::Count::Method::Concept

=head1 VERSION 1.10

=cut

has 'VoteValue' => (
  is      => 'ro',
  isa     => 'Int',
  default => 100000,
);

sub BUILD {
  my $I = shift ;
  $I->{'roundstatus'} = { 0 => { } };
  $I->{'currentround'} = 0;
}

sub Round($I) { return $I->{'currentround'}; }

sub NewRound ($I) {
  my $round = ++$I->{'currentround'};
  $I->{'roundstatus'}{$round} = {
    'charge' => {},
    'quota' => undef,
  };
  return $round;
}

sub SetQuota ($I) {
  # insure up to date TopCount before finding abandoned.
  my $abandoned = $I->CountAbandoned();
  my $abndnvotes = $abandoned->{'value_abandoned'};
  my $cast = $I->BallotSet->{'votescast'};
  my $numerator = ( $cast * $I->VoteValue ) - $abndnvotes ;
  my $denominator = $I->Seats() +1;
  return( 1 + int( $numerator /$denominator ) );
}


sub _preEstimate( $I, $quota, @elected ) {
  my $lastround = $I->{'currentround'} ? $I->{'currentround'} -1 : 0 ;
  my $lastcharge = $I->{'roundstatus'}{$lastround}{'charge'};
  my $unw = $I->LastTopCountUnWeighted();
  my %estimate = ();
  my %caps = ();
  for my $e (@elected ) {
    if( $lastcharge->{$e} ) {
      $estimate{ $e} = $lastcharge->{$e};
      $caps{$e} = $lastcharge->{$e};
    } else {
      $estimate{ $e} = int( $quota / $unw->{ $e} );
      $caps{$e} = $I->VoteValue;
    }
  }
  return (\%estimate, \%caps);
}

sub FullCharge ( $ballots, $cost, $active, $votevalue ) {
  for my $b ( keys $ballots->%* ) {
    $ballots->{$b}->{'votevalue'} = $votevalue; }
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
      }
    }
  }
  return \%chargedval;
}

sub _chargeInsight ( $I, $quota, $est, $cap, $freeze, @elected ) {
  my $active = $I->GetActive();
  my %estnew = ();
  my %elect = map { $_ => 1 } (@elected);
  my $B = dclone $I->GetBallots();
  my %charge = FullCharge ( $B, $est, $active, $I->VoteValue() )->%*;
  for my $E ( @elected ) {
    $charge{$E}{'surplus'} = $charge{$E}{'value'} - $quota ;
    $charge{$E}{'charge'} = $est->{$E};
    if ( $freeze->{$E} ) { $estnew{$E} = $freeze->{$E} } # if frozen stay frozen.
    elsif ( $charge{$E}{'surplus'} >= 0 ) {
      $estnew{$E}  =  $est->{$E} - int ( $charge{$E}{'surplus'} / $charge{$E}{'count'} );
    } else { $estnew{$E}
      = $est->{$E} - ( int( $charge{$E}{'surplus'} / $charge{$E}{'count'})) + 1 ;
    }
    $estnew{$E} = $cap->{$E} if $cap->{$E} < $estnew{$E} ; # apply cap.
  }
  return { 'result' => \%charge, 'est' => \%estnew };
}

sub CalcCharge ($I, $quota ) {
  my @elected = $I->Elected();
  my $round = $I->Round();
  my $estimates = {};
  my $iteration = 0;
  my $freeze = {};
  my ( $estimate, $cap )= _preEstimate( $I, $quota, @elected );
  $estimates->{0} = $estimate ;
  my $done = 0;
  until( $done or $iteration > 10 ) {
    ++$iteration;
    $I->ResetVoteValue();
    for my $E (@elected ) {
      my $TC = $I->TopCount();
      my $ballotsfor = $I->LastTopCountUnWeighted()->{$E};
      my $charged = $I->Charge( $E, $quota, $estimate->{$E} );
warn Dumper $charged;

    }
    last;
  }

return $estimate;
}

__PACKAGE__->meta->make_immutable;
1;
