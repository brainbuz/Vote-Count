use strict;
use warnings;
use 5.022;

use feature qw /postderef signatures/;

package Vote::Count::Approval;
use Moose::Role;

no warnings 'experimental';
# use Data::Printer;

sub Approval ( $self, $active=undef ) {
  my %BallotSet = $self->BallotSet()->%*;
  my %ballots = ( $BallotSet{'ballots'}->%* );
# p %ballots;
  $active = $BallotSet{'choices'} unless defined $active ;
# p $active;
  my %approval = ( map { $_ => 0 } keys( $active->%* ));
    for my $b ( keys %ballots ) {
# warn "checkijng $b";
# p $ballots{$b};
# return {};
      my @votes = $ballots{$b}->{'votes'}->@* ;
      for my $v ( @votes ) {
        if ( defined $approval{$v} ) {
          $approval{$v} += $ballots{$b}{'count'};
        }
      }
    }
  return Vote::Count::RankCount->Rank( \%approval );
}

1;