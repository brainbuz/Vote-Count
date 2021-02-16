use strict;
use warnings;
use 5.022;

package Vote::Count::Method::Cascade;
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
use JSON::MaybeXS;
use YAML::XS;
use Path::Tiny;
use Carp;
use Vote::Count::VoteCharge::Utility('FullCascadeCharge', 'NthApproval');

our $VERSION = '1.10';

=head1 NAME

Vote::Count::Method::Cascade

=head1 VERSION 1.10

=cut

has 'VoteValue' => (
  is      => 'ro',
  isa     => 'Int',
  default => 100000,
);

has 'IterationLog' => (
  is    => 'rw',
  isa   => 'Str',
  required => 0,
);

sub BUILD {
  my $I = shift;
  $I->{'roundstatus'}  = { 0 => {} };
  $I->{'currentround'} = 0;
}

our $coder = JSON->new->ascii->pretty;

sub Round($I) { return $I->{'currentround'}; }

sub NewRound ( $I, $quota = 0, $charge = {} ) {
  $I->TopCount();
  my $round = ++$I->{'currentround'};
  $I->{'roundstatus'}{ $round - 1 } = {
    'charge' => $charge,
    'quota'  => $quota,
  };
  return $round;
}

sub SetQuota ($I) {
  # insure up to date TopCount before finding abandoned.
  my $abandoned   = $I->CountAbandoned();
  my $abndnvotes  = $abandoned->{'value_abandoned'};
  my $cast        = $I->BallotSet->{'votescast'};
  my $numerator   = ( $cast * $I->VoteValue ) - $abndnvotes;
  my $denominator = $I->Seats() + 1;
  return ( 1 + int( $numerator / $denominator ) );
}

sub _preEstimate ( $I, $quota, @elected ) {
  my $lastround  = $I->{'currentround'} ? $I->{'currentround'} - 1 : 0;
  my $lastcharge = $I->{'roundstatus'}{$lastround}{'charge'};
  my $unw        = $I->LastTopCountUnWeighted();
  die 'LastTopCountUnWeighted failed' unless ( keys $unw->%* );
  my %estimate = ();
  my %caps     = ();
  for my $e (@elected) {
    if ( $lastcharge->{$e} ) {
      $estimate{$e} = $lastcharge->{$e};
      $caps{$e}     = $lastcharge->{$e};
    }
    else {
      $estimate{$e} = int( $quota / $unw->{$e} );
      $caps{$e}     = $I->VoteValue;
    }
  }
  return ( \%estimate, \%caps );
}

sub QuotaElectDo ( $I, $quota ) {
  my %TC        = $I->TopCount()->RawCount()->%*;
  my @Electable = ();
  for my $C ( keys %TC ) {
    if ( $TC{$C} >= $quota ) {
      $I->Elect($C);
      push @Electable, $C;
    }
  }
  return @Electable;
}


# Produce a better estimate than the previous by running
# FullCascadeCharge of the last estimate. Clones a copy of
# Ballots for the Cascade Charge.
sub _chargeInsight ( $I, $quota, $est, $cap, $bottom, $freeze, @elected ) {
  my $active = $I->GetActive();
  my %estnew = ();
  # make sure a new freeze is applied before charge evaluation.
  for my $froz ( keys $freeze->%* ) {
    $est->{$froz} = $freeze->{$froz} if $freeze->{$froz};
  }
  my %elect = map { $_ => 1 } (@elected);
  my $B     = dclone $I->GetBallots();
  my $charge =
    FullCascadeCharge( $B, $quota, $est, $active, $I->VoteValue() );
LOOPINSIGHT: for my $E (@elected) {
    if ( $freeze->{$E} ) {    # if frozen stay frozen.
      $estnew{$E} = $freeze->{$E};
      next LOOPINSIGHT;
    }
    elsif ( $charge->{$E}{'surplus'} >= 0 ) {
      $estnew{$E} =
        $est->{$E} - int( $charge->{$E}{'surplus'} / $charge->{$E}{'count'} );
    }
    else {
      $estnew{$E} = $est->{$E} -
        ( int( $charge->{$E}{'surplus'} / $charge->{$E}{'count'} ) ) + 1 ;
    }
    $estnew{$E} = $cap->{$E} if $cap->{$E} < $estnew{$E};    # apply cap.
    $estnew{$E} = $bottom->{$E}
      if $bottom->{$E} > $estnew{$E};                        # apply bottom.
  }
  return { 'result' => $charge, 'estimate' => \%estnew };
}

sub _write_iteration_log ( $I, $round, $data ) {
  if( $I->IterationLog() ) {
    my $jsonpath = $I->IterationLog() . ".$round.json";
    my $yamlpath = $I->IterationLog() . ".$round.yaml";
    path( $jsonpath )->spew( $coder->encode( $data ) );
    path( $yamlpath )->spew( Dump $data );
  }
}

sub CalcCharge ( $I, $quota ) {
  my @elected   = $I->Elected();
  my $round     = $I->Round();
  my $estimates = {};
  my $iteration = 0;
  my $freeze    = { map { $_ => 0 } @elected };
  my $bottom    = { map { $_ => 0 } @elected };
  my ( $estimate, $cap ) = _preEstimate( $I, $quota, @elected );
  $estimates->{$iteration} = $estimate;
  my $done = 0;
  my $charged = undef ; # the last value from loop is needed for log.
  until ( $done or $iteration > 20 ) {
    ++$iteration;
    # for ( $estimate, $cap, $bottom, $freeze, @elected ) { warn Dumper $_}
    $charged =
      _chargeInsight( $I, $quota, $estimate, $cap, $bottom, $freeze,
      @elected );
    $estimate                = $charged->{'estimate'};
    $estimates->{$iteration} = $charged->{'estimate'};
    $done                    = 1;
    for my $V (@elected) {
      my $est1 = $estimates->{$iteration}{$V};
      my $est2 = $estimates->{ $iteration - 1 }{$V};
      if ( $est1 != $est2 ) { $done = 0 }
    }
  }
  _write_iteration_log( $I, $round, {
    estimates => $estimates,
    quota => $quota,
    charge => $estimate,
    detail => $charged->{'result'} } );
  return $estimate;
}

__PACKAGE__->meta->make_immutable;
1;
