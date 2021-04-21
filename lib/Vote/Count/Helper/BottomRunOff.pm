package Vote::Count::Helper::BottomRunOff;

use 5.022;
no warnings 'experimental';
use feature ( 'signatures');

our $VERSION='1.10';

=head1 NAME

Vote::Count::Helper::BottomRunOff

=head1 VERSION 1.10

=head2 Description

Bottom RunOff is an elimination method which takes the two lowest choices, usually by Top Count, but alternately by another method such as Approval or Borda, the choice which would lose a runoff is eliminated.

=head1 Synopsis

  use Vote::Count::Helper::BottomRunOff
  my $eliminate = BottomRunOff( $Election, ....);

=head1 BottomRunOff

The method BottomRunOff is exported. Precedence must be setup,


=cut

# ABSTRACT: Helpers for Vote::Count

use Exporter::Easy (
  EXPORT => [ 'BottomRunOff' ] );

sub BottomRunOff ( $Election, $method1='TopCount' ) {
  my @ranked = $Election->UntieActive($method1, 'precedence' )->OrderedList();
  my ( $continuing, $loser ) = $Election->UnTieList( 'TopCount', $ranked[-1],  $ranked[-2]);
  my $tc = $Election->TopCount( { $continuing => 1,  $loser => 1} );
  return {
    loser => $loser,
    continuing => $continuing,
    runoff => "Elimination Runoff:\n${\ $tc->RankTable }"
  };
}

1;

#FOOTER

=pod

BUG TRACKER

L<https://github.com/brainbuz/Vote-Count/issues>

AUTHOR

John Karr (BRAINBUZ) brainbuz@cpan.org

CONTRIBUTORS

Copyright 2020,2019 by John Karr (BRAINBUZ) brainbuz@cpan.org.

LICENSE

This module is released under the GNU Public License Version 3. See license file for details. For more information on this license visit L<http://fsf.org>.

=cut
