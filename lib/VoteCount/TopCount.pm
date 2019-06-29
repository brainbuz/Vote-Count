use strict;
use warnings;
use 5.026;

use feature qw /postderef signatures/;

package VoteCount::TopCount;
use Moose::Role;

no warnings 'experimental';
use Data::Printer;

sub TopCount ( $self, $active=undef ) {
  my %ballotset = $self->ballotset()->%*;
  my %ballots = ( $ballotset{'ballots'}->%* );
# p %ballots;
  $active = $ballotset{'choices'} unless defined $active ;
# p $active;
  my %topcount = ( map { $_ => 0 } keys( $active->%* ));
TOPCOUNTBALLOTS:
    for my $b ( keys %ballots ) {
# warn "checkijng $b";
# p $ballots{$b};
# return {};
      my @votes = $ballots{$b}->{'votes'}->@* ;
      for my $v ( @votes ) {
        if ( defined $topcount{$v} ) {
          $topcount{$v} += $ballots{$b}{'count'};
          next TOPCOUNTBALLOTS;
        }
      }
    }
  return \%topcount;
}

1;