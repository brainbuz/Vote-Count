package Vote::Count::Method::WinnableAlternatives;

use 5.022;
use feature qw/postderef signatures/;
no warnings qw/experimental/;
use Path::Tiny 0.108;
use Carp;
# use Data::Dumper;
use Data::Printer;
# use Vote::Count::Method::CondorcetDropping;
use Vote::Count;
use Vote::Count::Method::IRV;
use Vote::Count::Matrix;
use Vote::Count::Redact qw/RedactSingle RedactPair/;
use Storable 3.15 qw(dclone);

sub _start ( $BallotSet, $Active=undef ) {
    my $Election = Vote::Count::Method::IRV->new(
      'BallotSet' => $BallotSet );
    $Election->logv(
      'First Choice Votes',
      $Election->TopCount->RankTable() );
    $Election->logv(
      'Approval Votes',
      $Election->Approval()->RankTable() );
    unless ( defined $Active ) { $Active = $Election->TCA() }
    $Election->Active($Active);
    my $Borda = $Election->Borda( $Active );
    $Election->logv( 'Borda Count', $Borda->RankTable() );
    my @Plurality = @{ $Election->TopCount()->ArrayTop() };
    return $Election;
    $Election->logv(
      "Borda Winner(s): " .
      join( ', ', @{($Borda->ArrayTop)}));
    if ( @Plurality > 1 ) {
      $Election->logv( "Plurality Tie @Plurality");
    } else {
      $Election->logv( "Plurality Winner $Plurality[0]");
    }
    return $Election;
}

sub _doredacted ( $BallotSet, $Active ) {
  my $M = Vote::Count::Matrix->new(
        'BallotSet' => $BallotSet,
        'Active'    => $Active
    );
  my $notice = '';
  if ( $M->CondorcetWinner() ) { return ( $M->CondorcetWinner(),
    'Winner Chosen by Condorcet' )}
  my $SmithSet = $M->SmithSet();
  $notice .= "No Condorcet Winner Smith Set: " .
    join( ", ", ( sort keys $SmithSet->%* ) ) . ' ' ;
  my $I = Vote::Count::Method::IRV->new(
        'BallotSet' => $BallotSet,
        'Active'    => $SmithSet
    );
  my $IRV = $I->RunIRV();
  if ( $IRV->{'winner'}){
    $notice .= "Winner Chosen by IRV. " ;
    return( $IRV->{'winner'}, $notice );
  } elsif ( $IRV->{'tied'}) {
    $notice .= "No IRV Winner, tie between: "  .
            join( ', ', $IRV->{'tied'}->@* )  ;
    return( '' , $notice );
  }
  else { croak "IRV failed" . Dumper $IRV }
}

sub ProtectedResults ( $E, $Active, $ignore ) {
  my @wins = ( $ignore );
  my @consider = map {
    if ( $_ eq $ignore) {} else {$_} } sort keys $Active->%* ;
  $E->logd(
    "ProtectedResults -- $ignore has a win already, now considering " .
    join( ', ', @consider ));
  for my $C ( @consider ) {
    my $redacted = RedactSingle( $E->BallotSet, $C );
    my ( $Win4C, $logentry ) = _doredacted( $redacted, $Active );
    $E->logd( "Result for $C redacted ballots  *$Win4C* $logentry" );
    push @wins, ( $C ) if ( $Win4C eq $C );
  }
  return @wins;
}

# return 1 if condorcet winner confirmed, 0 if not.
sub LaterHarmConfirm(
  $Election, $CondorcetWinner, $Alternate ) {

   $Election->logv( "+"x60,
      "+ Later Harm Confirmation $CondorcetWinner $Alternate +",
      "+"x60, );
my $M = Vote::Count::Matrix->new(
  'BallotSet' =>
   RedactPair( $Election->BallotSet(), $CondorcetWinner, $Alternate ),
   );
   $Election->logv(
        '+ TopCount With Redacted Ballots (Unchanged) +',
        $Election->TopCount()->RankTable(),
        '+ Approval With Redacted Ballots             +',
        $Election->Approval()->RankTable(),
        '+ Borda Count With Redacted Ballots          +',
        $Election->Borda()->RankTable(),
        'Condorcet Matrix Redacted Ballots            +',
        $M->MatrixTable(),
        'Condorcet Matrix Redacted Ballots            +',
        $M->ScoreTable(),
   );
   if( $CondorcetWinner eq $M->CondorcetWinner() ) {
     # $Winner = $CondorcetWinner;
     $Election->logv( "+ $CondorcetWinner is confirmed.");
     return 1;
   }
   # Pairing Margin between choices should be same in original
   # and redacted set, for convenience using the redacted copy.
   my $margin = abs $M->GetPairResult( $CondorcetWinner, $Alternate)->{'margin'} ;
   my $harmed = $M->GreatestLoss( $CondorcetWinner );

     $Election->logv( "+ $CondorcetWinner is not a Condorcet Winner with Redacted Ballots.");
     $Election->logv( "+ $CondorcetWinner defeated $Alternate by $margin");
     $Election->logv( "+ $CondorcetWinner greatest defeat is now $harmed");
     if ( $margin > $harmed ) {
      $Election->logt(
        "+ The margin of the Condorcet Winner $CondorcetWinner over "
        . "$Alternate is greater than their worst defeat, $CondorcetWinner "
        . "is confirmed.");
       return 1 ;
     } else {
      $Election->logt( "+ The margin of the Condorcet Winner $CondorcetWinner "
        . "over $Alternate is NOT greater than their worst defeat, $Alternate "
        . "is the winner, Ballots are Redacted.");
      return 0 ;
     }
}

sub Run ( $BallotSet ) {
    my $winner   = '';
    my $Election = _start($BallotSet);
    my $FloorActive = dclone( $Election->Active() );
    my $Matrix   = Vote::Count::Matrix->new(
        'BallotSet' => $BallotSet,
        'Active'    => $Election->Active()
    );
    my $MajWin = $Election->EvaluateTopCountMajority(
          undef, $FloorActive  )->{'winner'};
    if ( $MajWin) {
        $Election->logv( "Majority Winner $MajWin.");
        say $Election->logd();
        return $MajWin;
    }
    $Election->logv(
        'Condorcet Matrix and Scores',
        $Matrix->MatrixTable(),
        $Matrix->ScoreTable(),
    );
    my $CondorcetWinner = $Matrix->CondorcetWinner();
    unless ( $CondorcetWinner ) {
      my $SmithSet = $Matrix->SmithSet();
      $Election->logt( "No Condorcet Winner, Dominant Set is ",
            join ', ', sort( keys $SmithSet->%* ) );
      $Election->Active($SmithSet);
      $winner = $Election->RunIRV()->{'winner'};
      $Election->logt("IRV Winner in Dominant Set is $winner");
    }
    else {
      $Election->logt("Initial Condorcet Winner $CondorcetWinner");
      my @winnable =
        ProtectedResults( $Election, $FloorActive,  $CondorcetWinner);
      if ( @winnable == 1 ) {
        $Election->logt( "Condorcet Winner $CondorcetWinner Confirmed");
        $winner = $CondorcetWinner;
      } elsif (@winnable == 2 ) {
        $Election->logd( "possibilities: @winnable");
        $Election->Active( $FloorActive);
        LaterHarmConfirm( $Election, @winnable );
      }
      else {
        $Election->logt(
          "Multiple choices would win with Later Harm Protection: "
          . join( ', ', @winnable ));
        $winner = $CondorcetWinner;
        my $Finalists = {map { $_ => 1 } @winnable};
        $Election->Active($Finalists);
        $winner = $Election->RunIRV()->{'winner'};
        $Election->logt("IRV Winner of final Set is $winner");
        if ( $winner ne $CondorcetWinner ) {
          $Election->logt("Ballots redacted in favor of $winner");
          }
      }


    }

    say $Election->logd();
    return $winner;
}




1;