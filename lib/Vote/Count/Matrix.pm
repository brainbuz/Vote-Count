use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::Matrix;
use Moose;

no warnings 'experimental';
use List::Util qw( min max sum );
use Text::Table::Tiny  qw/generate_markdown_table/;

# use Try::Tiny;
use Data::Printer;
use Data::Dumper;

use YAML::XS;

has BallotSet => (
  is       => 'ro',
  required => 1,
  isa      => 'HashRef',
);

has BallotSetType => (
  is      => 'ro',
  isa     => 'Str',
  default => 'rcv',
);

has Active => (
  is      => 'rw',
  isa     => 'HashRef',
  builder => 'Vote::Count::Matrix::_buildActive',
  lazy    => 1,
);

sub _buildActive ( $self ) {
  return $self->BallotSet->{'choices'};
}

sub _conduct_pair ( $ballotset, $A, $B ) {
  my $ballots = $ballotset->{'ballots'};
  my $countA  = 0;
  my $countB  = 0;
FORVOTES:
  for my $b ( keys $ballots->%* ) {
    for my $v ( values $ballots->{$b}{'votes'}->@* ) {
      if ( $v eq $A ) {
        $countA += $ballots->{$b}{'count'};
        next FORVOTES;
      }
      elsif ( $v eq $B ) {
        $countB += $ballots->{$b}{'count'};
        next FORVOTES;
      }
    }
  }    # FORVOTES
  my %retval = (
    $A       => $countA,
    $B       => $countB,
    'tie'    => 0,
    'winner' => '',
    'loser'  => '',
    'margin' => abs( $countA - $countB )
  );
  if ( $countA == $countB ) {
    $retval{'winner'} = '';
    $retval{'tie'}    = 1;
  }
  elsif ( $countA > $countB ) {
    $retval{'winner'} = $A;
    $retval{'loser'}  = $B;
  }
  elsif ( $countB > $countA ) {
    $retval{'winner'} = $B;
    $retval{'loser'}  = $A;
  }
  return \%retval;
}

sub BUILD {
  my $self      = shift;
  my $results   = {};
  my $ballotset = $self->BallotSet();
  my @choices   = keys $self->Active()->%*;
  while ( scalar(@choices) ) {
    my $A = shift @choices;
    for my $B (@choices) {
      my $result = Vote::Count::Matrix::_conduct_pair( $ballotset, $A, $B );
      # Each result has two hash keys so it can be found without
      # having to try twice or sort the names for a single key.
      $results->{$A}{$B} = $result;
      $results->{$B}{$A} = $result;
    }
  }
  $self->{'Matrix'} = $results;
}

sub _scorematrix ( $self ) {
  my $scores = {};
  my %active = $self->Active()->%*;
  for my $A ( keys %active ) {
    my $hasties = 0;
    $scores->{$A} = 0;
    for my $B ( keys %active ) {
      next if $B eq $A;
        if( $A eq $self->{'Matrix'}{$A}{$B}{'winner'} ) { $scores->{$A}++ }
        if( $self->{'Matrix'}{$A}{$B}{'tie'} ) { $hasties = .001 }
    }
    if ( $scores->{$A} == 0 ) { $scores->{$A} += $hasties }
  }
  return $scores;
}

# return the choice with fewest wins in matrix.
sub LeastWins ( $matrix ) {
  my @lowest = ();
  my %scored = $matrix->_scorematrix()->%*;
      my $lowscore = min( values %scored );
      for my $A ( keys %scored ) {
        if ( $scored{ $A } == $lowscore ) {
          push @lowest, $A;
        }
      }
  return @lowest;
}

sub CondorcetLoser( $self ) {
  my $unfinished = 1;
  my $wordy      = "Removing Condorcet Losers\n";
  my @eliminated = ();
CONDORCETLOSERLOOP:
  while ($unfinished) {
    $unfinished = 0;
    my $scores = $self->_scorematrix;
    my @alist  = ( keys $self->Active()->%* );
    # Check that tied choices at the top won't be
    # eliminated. alist is looped over twice because we
    # don't want to report the scores when the list is
    # reduced to either a condorcet winner or tied situation.
    for my $A (@alist) {
      unless ( max( values $scores->%* ) ) {
        last CONDORCETLOSERLOOP;
      }
    }
    $wordy .= YAML::XS::Dump($scores);
    for my $A (@alist) {
      if ( $scores->{$A} == 0 ) {
        push @eliminated, ($A);
        $wordy .= "Eliminationg Condorcet Loser: *$A*\n";
        delete $self->{'Active'}{$A};
        $unfinished = 1;
        next CONDORCETLOSERLOOP;
      }
    }
  }
  my $elimstr =
    scalar(@eliminated)
    ? "Eliminated Condorcet Losers: " . join( ', ', @eliminated ) . "\n"
    : "No Condorcet Losers Eliminated\n";
  return {
    verbose => $wordy,
    terse   => $elimstr,
    eliminated => \@eliminated,
    eliminations => scalar(@eliminated),
  };
}

sub CondorcetWinner( $self ) {
  my $scores = $self->_scorematrix;
  my @choices = keys $scores->%*;
  # # if there is only one choice left they win.
  # if ( scalar(@choices) == 1 ) { return $choices[0]}
  my $mustwin = scalar(@choices) -1;
  my $winner = '';
  for my $c (@choices) {
    if ( $scores->{$c} == $mustwin) {
      $winner .= $c;
    }
  }
  return $winner;
}

sub _getsmithguessforchoice ( $h, $matrix ) {
  my @winners = ($h);
  for my $P ( keys $matrix->{$h}->%* ) {
    if ( $matrix->{$h}{$P}{'winner'} eq $P ) {
      push @winners, ($P);
    }
    elsif ( $matrix->{$h}{$P}{'tie'} ) {
      push @winners, ($P);
    }
  }
  return ( map { $_ => 1 } @winners );
}

sub SmithSet ( $self ) {
  my $matrix    = $self->{'Matrix'};
  my @alist     = ( keys $self->Active()->%* );
  my $sets      = {};
  my $setcounts = {};
  # my $shortest = scalar(@list);
  for my $h (@alist) {
    my %set = Vote::Count::Matrix::_getsmithguessforchoice( $h, $matrix );
    $sets->{$h} = \%set;
    # the keys of setcounts are the counts
    $setcounts->{ scalar( keys %set ) }{$h} = 1;
  }
  my $proposal = {};
  my $minset   = min( keys( $setcounts->%* ) );
  for my $h ( keys $setcounts->{$minset}->%* ) {
    for my $k ( keys( $sets->{$h}->%* ) ) {
      $proposal->{$k} = 1;
    }
  }
SMITHLOOP: while (1) {
    my $cntchoice = scalar( keys $proposal->%* );
    for my $h ( keys $proposal->%* ) {
      $proposal = { %{$proposal}, %{ $sets->{$h} } };
    }
    # done when no choices get added on a pass through loop
    if ( scalar( keys $proposal->%* ) == $cntchoice ) {
      last SMITHLOOP;
    }
  }
  return $proposal;
}

# options may later be used to add rankcount objects
# from boorda, approval, and topcount.
sub MatrixTable ( $self, $options = {} ) {
  my @header = ( 'Choice', 'Wins', 'Losses', 'Ties' );
  my $o_topcount = defined $options->{'topcount'}
    ? $options->{'topcount'} : 0;
  push @header, 'Top Count' if $o_topcount;
  my @active = sort ( keys $self->Active()->%* );
  my @rows = ( \@header );    # [ 'Rank', 'Choice', 'TopCount']);
  for my $A (@active) {
    my $wins   = 0;
    my $ties   = 0;
    my $losses = 0;
    my $topcount = $o_topcount ? $options->{'topcount'}{$A} : 0;
  MTNEWROW:
    for my $B (@active) {
      if ( $A eq $B ) { next MTNEWROW }
      elsif ( $self->{'Matrix'}{$A}{$B}{'winner'} eq $A ) {
        $wins++;
      }
      elsif ( $self->{'Matrix'}{$A}{$B}{'winner'} eq $B ) {
        $losses++;
      }
      elsif ( $self->{'Matrix'}{$A}{$B}{'tie'} ) {
        $ties++;
      }
    }
    my @newrow = ( $A, $wins, $losses, $ties);
    push @newrow, $topcount if $o_topcount ;
    push @rows, \@newrow;
  }
  return generate_markdown_table( rows => \@rows );
}

1;
