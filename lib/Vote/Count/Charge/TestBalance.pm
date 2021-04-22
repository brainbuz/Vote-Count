use strict;
use warnings;
use 5.024;
# use feature qw /postderef signatures/;

package Vote::Count::Charge::TestBalance;
use Test2::API qw/context/;

our @EXPORT = qw/balance_ok/;
use base 'Exporter';

sub balance_ok :prototype($$$$;$) {
  my ( $Ballots, $charge, $balance, $elected, $name ) = @_;
  $name = 'check balance of charges and votes' unless $name;
  my $valelect = 0;
  for ( @{$elected} ) {
    $valelect += $charge->{$_}{'value'};
  }
  my $valremain = 0;
  for my $k ( keys $Ballots->%* ) {
    $valremain +=
      $Ballots->{$k}{'votevalue'} * $Ballots->{$k}{'count'};
  }
  my $valsum = $valremain + $valelect;
  my $warning = "### $valsum ($valremain + $valelect) != $balance ###";
  my $ctx = context();    # Get a context
    $ctx->ok( $valsum == $balance, $name, [ "$name\n\t$warning"] );
  $ctx->release;    # Release the context
  return 1;
}

1;

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

=cut

