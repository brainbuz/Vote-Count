use strict;
use warnings;
use 5.024;

package Vote::Count::Helper::NthApproval;
no warnings 'experimental';
use feature qw /postderef signatures/;
use Sort::Hash;
use Vote::Count::TextTableTiny qw/generate_table/;

our $VERSION = '1.10';

# ABSTRACT: Non OO Components for the Vote::Charge implementation of STV.

=head1 NAME

Vote::Count::Helper::NthApproval

=head1 VERSION 1.10

=cut

=pod

=head1 SYNOPSIS

  use Vote::Count::Helper::NthApproval;
  for my $defeat ( NthApproval( $STV_Election ) ) {
     $STV_Election->Defeat( $defeat );
  }

=head1 NthApproval

Finds the choice that would fill the last seat if the remaining seats were to be filled by highest Top Count, and sets the Vote Value for that Choice as the requirement. All Choices that do not have a weighted Approval greater than that requirement are returned, they will never be elected and are safe to defeat immediately.

Results are logged to the verbose log,

=cut

use Exporter::Easy (
  EXPORT => [ 'NthApproval' ],
);

sub NthApproval ( $I ) {
  my $tc            = $I->TopCount();
  my $ac            = $I->Approval();
  my $seats         = $I->Seats() - $I->Elected();
  my @defeat        = ();
  my $bottomrunning = $tc->HashByRank()->{$seats}[0];
  my $bar           = $tc->RawCount()->{$bottomrunning};
  for my $A ( $I->GetActiveList ) {
    next if $A eq $bottomrunning;
    my $avv = $ac->{'rawcount'}{$A};
    push @defeat, ($A) if $avv <= $bar;
  }
  if (@defeat) {
    $I->logv( qq/
      Seats: $seats Choice $seats: $bottomrunning ( $bar )
      Choices Not Over $bar by Weighted Approval: ${\ join( ', ', @defeat ) }
    /);
  }
  return @defeat;
}

1;
