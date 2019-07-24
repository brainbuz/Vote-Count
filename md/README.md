# Voting::Methods

## A Toolkit for determining the outcome of Ranked Choice and other Alternative Balloting Strategies.

## Audience

### Policy People and Choice Activists

The toolkit allows for building customized resolution systems. Components are provided for common operations accross multiple resolution systems such as Top and Approval counts.`

### Mathematicians and Data Scientists

For the Math community involved in Choice Mathematics, the tool kit will make it easier to build similations of multiple methods with room for customization.

# Synopsis

```perl
use 5.022; # Minimum Perl, or any later Perl.
use feature qw /postderef signatures/;

use Vote::Count;
use Vote::Count::Method::CondorcetDropping;
use Vote::Count::ReadBallots 'read_ballots';

my $ballotset = read_ballots 'my_ballot_file';
my $Election = Vote::Count->new( BallotSet => $ballotset)

```
