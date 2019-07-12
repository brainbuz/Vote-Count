use strict;
use warnings;
use 5.026;

package Vote::Count::RankCount;

use feature qw /postderef signatures/;
no warnings 'experimental';
use List::Util qw( min max );
use Text::Table::Tiny  qw/generate_markdown_table/;
# use boolean;
use Data::Printer;

sub _RankResult ( $rawcount ) {
  my %rc      = $rawcount->%*;    # destructive process needs to use a copy.
  my %ordered = ();
  my %byrank  = () ;
  my $pos = 0;
  my $maxpos = scalar( keys %rc ) ;
  while ( 0 < scalar( keys %rc ) ) {
    $pos++;
    my @vrc      = values %rc;
    my $max      = max @vrc;
    for my $k ( keys %rc ) {
      if ( $rc{$k} == $max ) {
        $ordered{$k} = $pos;
        delete $rc{ $k };
        if ( defined $byrank{$pos} ) {
          push @{ $byrank{$pos} }, $k;
        }
        else {
          $byrank{$pos} = [ $k ];
        }
      }
    }
    die "Vote::Count::RankCount::Rank in infinite loop\n" if
      $pos > $maxpos ;
    ;
  }
  # %byrank[1] is arrayref of 1st position,
  # $pos still has last position filled, %byrank{$pos} is the last place.
  # sometimes byranks came in as var{byrank...} deref and reref fixes this
  # although it would be better if I understood why it happened.
  # It is useful to sort the arrays anyway, for display they would likely be
  # sorted anyway. For testing it makes the element order predictable.
  my @top = sort @{$byrank{1}} ;
  my @bottom = sort @{$byrank{ $pos }};
  return {
    'rawcount' => $rawcount,
    'ordered' => \%ordered,
    'byrank' => \%byrank,
    'top' => \@top,
    'bottom' => \@bottom,
    };
}

sub Rank ( $class, $rawcount ) {
  my $I = _RankResult( $rawcount);
# p $I;
  return bless $I, $class;
}

sub RawCount ( $I ) { return $I->{'rawcount'} }
sub HashWithOrder ( $I ) { return $I->{'ordered'} }
sub HashByRank ( $I ) { return $I->{'byrank'} }
sub ArrayTop ( $I ) { return  $I->{'top'} }
sub ArrayBottom ( $I ) { return $I->{'bottom'} }
# sub ArrayTop ( $I ) { return [sort $I->{'top'}->@* ] }
# sub ArrayBottom ( $I ) { return [sort $I->{'bottom'}->@* ] }

sub RankTable( $self ) {
  my @rows = ( [ 'Rank', 'Choice', 'Votes']);
  my %rc = $self->{'rawcount'}->%*;
  my %byrank = $self->{'byrank'}->%*;
  for my $r ( sort keys %byrank ) {
    my @choice = sort $byrank{$r}->@*;
    for my $choice ( @choice ) {
      my $votes = $rc{$choice};
      my @row = ( $r, $choice, $votes );
      push @rows, (\@row);
    }
  }
  return generate_markdown_table( rows => \@rows );
}

1;