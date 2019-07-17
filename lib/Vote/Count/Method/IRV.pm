use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::Method::IRV;

use namespace::autoclean;
use Moose;
extends 'Vote::Count';
# Brings the main Vote::Count Object in along with
# Topcount and other methods.
# with 'Vote::Count';
# with 'Vote::Count::Matrix';

our $VERSION='0.003';

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
  my $roundctr   = 0;
  my $maxround   = scalar( keys %{$active} );
  $self->logt( "Instant Runoff Voting",
    'Choices: ', join( ', ', ( sort keys %{$active} ) ) );
# forever loop normally ends with return from $majority
# a tie should be detected and also generate a
# return from the else loop.
# if something goes wrong roundcountr/maxround
# will generate exception.
IRVLOOP:
  until ( 0 ) {
    $roundctr++;
    die "IRVLOOP infinite stopped at $roundctr" if $roundctr > $maxround;
    my $round = $self->TopCount($active);
    $self->logv( '---', "IRV Round $roundctr", $round->RankTable() );
    my $majority = $self->EvaluateTopCountMajority( $round );
    if ( defined $majority->{'winner'} ) {
      return $majority;
    } else {
      my @bottom = sort $round->ArrayBottom()->@*;
      if ( scalar(@bottom) == scalar( keys %{$active} ) ) {
        # if there is a tie at the end, the finalists should
        # be both top and bottom and the active set.
        $self->logt( "Tied: " . join( ', ', @bottom ) );
        return { tie => 1, tied => \@bottom, winner => 0  };
      }
      $self->logv( "Eliminating: " . join( ', ', @bottom ) );
      for my $b (@bottom) {
        delete $active->{$b};
      }
    }
  }
}

1;

#buildpod

=pod

=head1 IRV

Some things to know about IRV.


=head2 Warning

IRV is the best algorithm for resolving a small Condorcet Tie, but
a poor algorithm for an election. But it is really simple.

=cut

#buildpod