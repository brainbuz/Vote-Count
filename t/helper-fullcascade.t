#!/usr/bin/env perl

use 5.024;
# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
# use Test::Exception;
# use Data::Dumper;

use Path::Tiny;
use Try::Tiny;
use Storable 'dclone';

use Vote::Count;
use Vote::Count::ReadBallots 'read_ballots', 'read_range_ballots';

use feature qw /postderef signatures/;
no warnings 'experimental';

ok 1;

done_testing();