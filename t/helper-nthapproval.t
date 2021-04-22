#!/usr/bin/env perl

use 5.024;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
# use Test::Exception;
# use Data::Dumper;

# use Path::Tiny;
# use Try::Tiny;
# use Storable 'dclone';

use Vote::Count::Charge;
use Vote::Count::ReadBallots 'read_ballots', 'read_range_ballots';
use Vote::Count::Helper::NthApproval;

use feature qw /postderef signatures/;
no warnings 'experimental';

  my $B =
    Vote::Count::Charge->new(
      Seats     => 2,
      BallotSet => read_ballots('t/data/data2.txt'),
      VoteValue => 100,
    );
  is_deeply(
    [ sort ( NthApproval($B) ) ],
    [ qw( CARAMEL PISTACHIO ROCKYROAD RUMRAISIN STRAWBERRY ) ],
    'returned list to eliminate'
  );
  my $C =
    Vote::Count::Charge->new(
      Seats     => 3,
      BallotSet => read_ballots('t/data/data2.txt'),
      VoteValue => 100,
    );
  is_deeply(
    [ sort ( NthApproval($C) ) ],
    [ qw( CARAMEL ROCKYROAD RUMRAISIN ) ],
    'another choice had approval == Nth place topcount'
  );

done_testing();