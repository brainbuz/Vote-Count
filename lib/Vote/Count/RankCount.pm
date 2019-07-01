use strict;
use warnings;
use 5.026;

use feature qw /postderef signatures/;

package Vote::Count::RankCount;
no warnings 'experimental';
use List::Util qw( min max );
use boolean;
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
  my @top = @{$byrank{1}} ;
  my @bottom = @{$byrank{ $pos }};
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

sub RawCount ( $I ) { return $I->{'rawcount'}->%* }
sub HashWithOrder ( $I ) { return $I->{'ordered'}->%* }
sub HashByRank ( $I ) { return $I->{'byrank'}->%* }
sub ArrayTop ( $I ) { return sort $I->{'top'}->@* }
sub ArrayBottom ( $I ) { return sort $I->{'bottom'}->@* }

1;