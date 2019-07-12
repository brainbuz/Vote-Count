use strict;
use warnings;
use 5.026;
use feature qw /postderef signatures/;

package Vote::Count::Method::IRV;
use namespace::autoclean;
use Moose;
extends 'Vote::Count';
# Brings the main Vote::Count Object in along with
# Topcount and other methods.
# with 'Vote::Count';
# with 'Vote::Count::Matrix';

no warnings 'experimental';
use List::Util qw( min max );

# use Vote::Count::RankCount;
# use Try::Tiny;
use Text::Table::Tiny 'generate_markdown_table';
use Data::Printer;
use Data::Dumper;

# use YAML::XS;

sub RunIRV ( $self, $active = undef ) {
  unless ( defined $active ) {
    $active = $self->BallotSet->{'choices'};
  }
  my $winner     = undef;
  my $roundctr   = 0;
  my $maxround   = scalar( keys %{$active} );
  my $resulthash = {};
  $self->logt( "Instant Runoff Voting",
    'Choices: ', join( ', ', ( sort keys %{$active} ) ) );
IRVLOOP:
  until ( defined $winner ) {
    $roundctr++;
    die "IRVLOOP infinite stopped at $roundctr" if $roundctr > $maxround;
    my $round = $self->TopCount($active);
    $self->logv( '---', "IRV Round $roundctr", $round->RankTable() );
    my $majority = $self->TopCountMajority( $round, $active );
    if ( $majority->{'winner'} ) {
      $winner = $majority->{'winner'};
      my $rows = [
        [ 'Winner',                    $winner ],
        [ 'Votes in Final Round',      $majority->{'votes'} ],
        [ 'Votes Needed for Majority', $majority->{'thresshold'} ],
        [ 'Winning Votes',             $majority->{'winvotes'} ],
      ];
      $resulthash = {
        winner     => $winner,
        votes      => $majority->{'votes'},
        winvotes   => $majority->{'winvotes'},
        thresshold => $majority->{'thresshold'}
      };
      $self->logt(
        '---',
        generate_markdown_table(
          rows       => $rows,
          header_row => 0
        )
      );
    }
    else {
      my @bottom = sort $round->ArrayBottom()->@*;
      if ( scalar(@bottom) == scalar( keys %{$active} ) ) {
        # if there is a tie at the end, the finalists should
        # be both top and bottom and the active set.
        $self->logt( "Tied: " . join( ', ', @bottom ) );
        return { tie => 1, tied => \@bottom };
      }
      $self->logv( "Eliminating: " . join( ', ', @bottom ) );
      for my $b (@bottom) {
        delete $active->{$b};
      }
    }
  }
  return $resulthash;
}

1;
