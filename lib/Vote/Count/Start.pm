package Vote::Count::Start;

use 5.024;
use strict;
use warnings;
use feature qw/postderef signatures/;
no warnings qw/experimental/;
use Path::Tiny 0.108;
use Carp;
use Try::Tiny;
# use Data::Dumper;
# use Vote::Count::Method::CondorcetDropping;
use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots';

our $VERSION='2.04';

=head1 NAME

Vote::Count::Start

=head1 VERSION 2.04

=cut

# ABSTRACT: Vote::Count Common Setup

=head1 SYNOPSIS

  use Vote::Count::Start;

  my $Election = StartElection(
    BallotFile => $filepath,
    FloorRule => 'TopCount',
    FloorValue => 2,
    LogPath -> '/some/path',
    ...
  );

  $Election->WriteLog();

=head1 Description

Does common startup steps useful accross methods. It includes a lot of the boiler plate for common usage. Use for resolving elections where the rules don't require customization, or as an example for writing more customized methods.

=over

* Reads Ballots from a file/path

* Calculates and logs Top Count

* Calculates and logs Approval

* Applies a Floor Rule

* Calculatures and logs a Borda Count

* Generates a Condorcet Matrix and logs the Win/Loss Summary and the Scores

* Conducts IRV (default options) and logs the result

* Returns a Vote::Count Object

=back

=head1 Method StartElection

Returns a Vote::Count object performing the above operations.

=head2 Parameter BallotSet or BallotFile

It is mandatory to provide either a reference to a BallotSet or to provide a BallotFile for ReadBallots to create a BallotSet.

=head2 Paramater FloorRule, FloorValue (optional)

A FloorRule and optional value (see Vote::Count::Floor). If no FloorRule is provide none will be used.

=head2 Other Options

Any other option to Vote::Count can just be passed in the arguments list

=cut

use Exporter::Easy ( EXPORT => ['StartElection'] );

# checks for ballotfile and updates the ballotset in
# args. no return value because %ARGS is passed by reference
# and updated directly if needed.
sub _ballotset( $ARGS ) {
  if ( $ARGS->{'BallotFile'} ) {
    $ARGS->{'BallotSet'} = read_ballots $ARGS->{'BallotFile'};
  }
  # If
  unless ( defined( $ARGS->{'BallotSet'}{'choices'} ) ) {
    croak "A Valid BallotSet or BallotFile was not provided "
      . $ARGS->{'BallotFile'} . "\n";
  }
}

sub _dofloor ( $self, %ARGS ) {
  unless ( defined $ARGS{'FloorRule'} ) {
    return $self->Active();
  }
  $self->logv('');    # log a blank line.
  my $flr      = $ARGS{'FloorRule'};
  my $floorset = {};
  if ( $flr eq 'TopCount' ) {
    $floorset = $self->TopCountFloor( $ARGS{'FloorValue'} );
  }
  elsif ( $flr eq 'TCA' ) {
    $floorset = $self->TCA();
  }
  elsif ( $flr eq 'Approval' ) {
    $floorset = $self->ApprovalFloor( $ARGS{'FloorValue'} );
  }
  else {
    croak "Undefined Floor rule $flr.\n";
  }
  $self->logv('');    # add blank line to output
  return $floorset;
}

sub _do_plurality ( $Election ) {
  my $Plurality = $Election->TopCount();
  $Election->logv(
    ' ',
    'Initial Top Count (Plurality)',
    $Plurality->RankTable()
  );
  my $PluralityTop = $Plurality->Leader();
  if ( $PluralityTop->{'winner'} ) {
    $Election->logt( "Plurality Winner: " . $PluralityTop->{'winner'} );
    return $PluralityTop->{'winner'};
  }
  else {
    $Election->logt(
      "Plurality Tie: " . join( ', ', $PluralityTop->{'tied'}->@* ) );
    return '';
  }
}

sub _do_approval ( $Election ) {
  my $Approval = $Election->Approval();
  $Election->logv( "\nApproval", $Approval->RankTable() );
  my $AWinner = $Approval->Leader();
  if ( $AWinner->{'winner'} ) {
    $Election->logt( "Approval Winner: " . $AWinner->{'winner'} );
    return $AWinner->{'winner'};
  }
  else {
    $Election->logt(
      "Approval Tie: " . join( ', ', $AWinner->{'tied'}->@* ) );
    return '';
  }
}

sub _do_borda ( $Election ) {
  my $Borda = $Election->Approval();
  $Election->logv( "Borda Count", $Borda->RankTable(), );
  my $AWinner = $Borda->Leader();
  if ( $AWinner->{'winner'} ) {
    $Election->logt( "Borda Winner: " . $AWinner->{'winner'}, '' );
    return $AWinner->{'winner'};
  }
  else {
    $Election->logt( "Borda Tie: " . join( ', ', $AWinner->{'tied'}->@* ),
      '' );
    return '';
  }
}

sub _do_majority( $Election) {
  my $majority = $Election->TopCountMajority();
  if ( $majority->{'winner'} ) {
    $Election->logv( "Majority Winner: " . $majority->{'winner'} );
    return $majority->{'winner'};
  }
  else { return ''; }
}

sub _do_matrix( $Election) {
  my $matrix = $Election->PairMatrix();
  $Election->logv(
    "Pairing Results:",
    $matrix->MatrixTable(),
    "\nSmith Set: " . join( ', ', sort( keys $matrix->SmithSet()->%* ) )
  );
  if ( $matrix->CondorcetWinner() ) {
    $Election->logv( "Condoret Winner: " . $matrix->CondorcetWinner() );
    return $matrix->CondorcetWinner();
  }
  else { return '' }
}

sub _do_irv ( $Election, $floorset ) {
  my $IRVResult = try { $Election->RunIRV() }
  catch { croak "RunIRV exploded" };
}

sub StartElection ( %ARGS ) {
  my $winners = {};
  _ballotset( \%ARGS );
  delete $ARGS{'BallotFile'};
  my $FloorValue = delete $ARGS{'FloorValue'};
  my $FloorRule = delete $ARGS{'FloorRule'};
  my $Election = Vote::Count->new(%ARGS);
  $winners->{'plurality'} = _do_plurality($Election);
  $winners->{'approval'}  = _do_approval($Election);
  my $floorset = _dofloor( $Election, 'FloorRule' => $FloorRule, 'FloorValue' => $FloorValue );
  $Election->SetActive($floorset);
  $winners->{'majority'}  = _do_majority($Election);
  $winners->{'borda'}     = _do_borda($Election);
  $winners->{'condorcet'} = _do_matrix($Election);
  $winners->{'irv'}       = _do_irv( $Election, $floorset );
  # todo generate a summary from the winners hash.
  $Election->{'startdata'} = $winners;
  # Active gets modified from default, so reset to floorset
  $Election->SetActive($floorset);
  return ($Election);
}

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

This software is provided as is, per the terms of the GNU Public License. Professional support and customisation services are available from the author.

=cut

