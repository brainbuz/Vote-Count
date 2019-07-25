use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

# ABSTRACT: toolkit for implementing voting methods.

package Vote::Count;
use namespace::autoclean;
use Moose;

# use Data::Printer;
use Time::Piece;

no warnings 'experimental';


our $VERSION='0.011';

=head1 NAME

Vote::Count

=head1 VERSION 0.011

=cut

# ABSTRACT: Parent Module for Vote::Count. Toolkit for vote counting.

has 'BallotSet' => ( is => 'ro', isa => 'HashRef' );
has 'BallotSetType' => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default =>  'rcv',
);

has 'Active' => (
  is => 'rw',
  isa => 'HashRef',
  lazy => 1,
  builder => '_buildactive', );

sub _buildactive ( $self ) { return  $self->BallotSet()->{'choices'} }

sub BUILD {
  my $self      = shift;
  # Verbose Log
  $self->{'LogV'} = localtime->cdate . "\n" ;
  # Debugging Log
  $self->{'LogD'} = qq/Vote::Count Version $VERSION\n/;
  $self->{'LogD'} .= localtime->cdate . "\n" ;
  # Terse Log
  $self->{'LogT'} = '';
}

sub logt {
  my $self = shift @_;
  return $self->{'LogT'} unless ( @_) ;
  my $msg = join( "\n", @_ ) . "\n";
  $self->{'LogT'} .= $msg;
  $self->{'LogV'} .= $msg;
  $self->logd( @_);
}

sub logv {
  my $self = shift @_;
  return $self->{'LogV'} unless ( @_) ;
  my $msg = join( "\n", @_ ) . "\n";
  $self->{'LogV'} .= $msg;
  $self->logd( @_);
}

sub logd {
  my $self = shift @_;
  return $self->{'LogD'} unless ( @_) ;
  my @args = (@_);
  # since ops are seqential and fast logging event times
  # clutters the debug log.
  # unshift @args, localtime->date . ' ' . localtime->time;
  my $msg = join( "\n", @args ) . "\n";
  $self->{'LogD'} .= $msg;
}

# load the roles providing the underlying ops.
with  'Vote::Count::Approval',
      'Vote::Count::TopCount',
      'Vote::Count::Borda',
      'Vote::Count::Floor'
      ;

sub CountBallots ( $self ) {
  my $ballots = $self->BallotSet()->{'ballots'};
  my $numvotes = 0;
  for my $ballot ( keys $ballots->%* ) {
    $numvotes += $ballots->{$ballot}{'count'};
  }
  return $numvotes;
}

__PACKAGE__->meta->make_immutable;
1;

#buildpod

=pod

=head1 Vote::Count


=head2 A Toolkit for determining the outcome of Ranked Choice and other Alternative Balloting Strategies.

Provides a Toolkit for implementing multiple voting systems, allowing a wide range of method options. This library allows the creation of election resolution methods matching a set of Election Rules that are written in an organization's governing rules, and not requiring the bylaws to specify the rules of the software that will be used for the election, especially important given that many of the other libraries available do not provide a bylaws compatible explanation of their process.

This is also extremely useful to researchers who may want to study multiple methods and variations of methods.


=head1 Synopsis

```perl
use 5.022; # Minimum Perl, or any later Perl.
use feature qw /postderef signatures/;

use Vote::Count;
use Vote::Count::Method::CondorcetDropping;
use Vote::Count::ReadBallots 'read_ballots';


=head1 example uses biggerset1 from the distribution test data.

my $ballotset = read_ballots 't/data/biggerset1.txt' ;
my $CondorcetElection =
  Vote::Count::Method::CondorcetDropping->new(
    'BallotSet' => $ballotset ,
    'DropStyle' => 'all',
    'DropRule'  => 'topcount',
  );


=head1 ChoicesAfterFloor a hashref of choices meeting the


=head1 ApprovalFloor which defaulted to 5%.

my $ChoicesAfterFloor = $CondorcetElection->ApprovalFloor();


=head1 Apply the ChoicesAfterFloor to the Election.

$CondorcetElection->Active( $ChoicesAfterFloor );


=head1 Get Smith Set and the Election with it as the Active List.

my $SmithSet = $CondorcetElection->Matrix()->SmithSet() ;
$CondorcetElection->logt(
  "Dominant Set Is: " . join( ', ', keys( $SmithSet->%* )));
my $Winner = $CondorcetElection->RunCondorcetDropping( $SmithSet );


=head1 Create an object for IRV, use the same Floor as Condorcet

my $IRVElection = Vote::Count::Method::IRV->new(
  'BallotSet' => $ballotset,
  'Active' => $ChoicesAfterFloor );


=head1 Get a RankCount Object for the

my $Plurality = $IRVElection->TopCount();


=head1 In case of ties RankCount objects return top as an array, log the result.

my $PluralityWinner = $Plurality->Leader();
$IRVElection->logv( "Plurality Results", $Plurality->RankTable);
if ( $PluralityWinner->{'winner'}) {
  $IRVElection->logt( "Plurality Winner: ", $PluralityWinner->{'winner'} )
} else {
  $IRVElection->logt(
    "Plurality Tie: " . join( ', ', $PluralityWinner->{'tied'}->@*) )
}
my $IRVResult = $IRVElection->RunIRV();


=head1 Now print the logs and winning information.

note $CondorcetElection->logv();
note $IRVElection->logv();
note 'B<>B<>B<>B<>**';
note "Plurality Winner: $PluralityWinner->{'winner'}";
note "IRV Winner: $IRVResult->{'winner'}";
note "Winner: $Winner";

```


=head1 Preview Release

This module is not ready for production.


=head1 Overview


=head2 Brief Review of Voting Methods

Several alternatives have been proposed to the simple vote for a single choice method that has been used in most elections for a single member. In addition a number of different methods have been used for multiple members. For alternative single member voting, the three common alternatives are I<Approval> (voters indicate all choices that they approve of), I<Ranked Choice> (Voters rank the choices), and I<Score> also known as I<Range> (A Ranked Choice Ballot where the number of rankings is limited but voters may rank more than 1 choice at each rank).

I<Vote for One> ballots may be resolved by one of two methods: I<Majority> and I<Plurality>. Majority vote requires a majority of votes to win (but frequently produces no winner), and Plurality which selects the choice with the most votes.

Numerous methods have been proposed and tried for I<Ranked Choice Ballots>. To compare these methods a number of criteria have been developed. While Mathematicians often treat these criteria as absolutes, from a policy perspective it may be more valuable to see them as a spectrum where a method may be considered to satisfy or fail with varying degrees of severity. From a policy perspective it is appropriate to group several of the criteria into a single group: Consistency. Finally typically Mathematicians do not directly consider Complexity, but from a policy perspective this is just as important as any of the other criteria, and is definitely a scale not an absolute.


=head3 The Criteria for Resolving Ranked Choice (including Score) Ballots


=head4 Later Harm

Marking a later Choice on a Ballot should not cause a Voter's higher ranked choice to lose.


=head4 Condorcet Criteria

I<Condorcet Loser> states that a method should not choose a winner that would be defeated in a direct matchup to all other choices.

I<Condorcet Winner> states a choice which defeats all others in direct matchups should be the Winner.

I<Smith Criteria> if there is a set of choices which defeats all others in direct matchups the winner should be one of those choices.


=head4 Consistency Criteria

The Consistency Criteria collectively state: Changes to non-winning alternatives that would not obviously alter the outcome should not change the winner. Adding or removing non-winning choices, or altering the votes for non-winning choices, except in a manner which directly changes the outcome should not alter the outcome. If votes are moved between non-winning alternatives in a manner that has no direct affect on the winner, the winner should not change. Changes to non-winning choices which increase support for the winner should not then cause a different choice to win.

To illustrate inconsistency: suppose every morning we vote on a flavor of Ice Cream and Chocolate always wins; one morning the three voters who always vote 1:RockyRoad 2:Chocolate simply vote for Chocolate, consistency is violated if Chocolate loses on that day.

Cloning occurs when similar choices are available, such as Vanilla and Vanilla Bean. If removing one of the clones would cause the other to win, the presence of both should not cause a non-clone to win.

The cases described bove:Monotonocity, Independence of Irrelevant Alternatives and Clone Independence are normally discussed as seperate criteria rather than components of one. Additional sub-criteria that haven't been mentioned include: Reversal Symmetry, Participation Consistency, and Later No Help (which could also be considered a sub-criteria of Later Harm).


=head4 Complexity

Is it feasible to count 100 ballots by hand? How difficult is it to understand the process (can the average middle school student understand it at all)? How many steps?


=head4 Resolvability

I<Majority> meets all of the above criteria, however, unless votes are restricted to two choices, it will frequently fail to provide a winner, or even a tie. No method can be completely impervious to ties. Methods that are not Resolveable are frequently combined with other methods, I<Instant Runoff Voting> is a compound method with I<Majority>, and all usable I<Condorcet> Methods combine seeking a Condorcet Winner with some other process for when there isn't one.


=head4 Incentive for Strategic Voting

Voting systems have weaknesses which can incentivize voter to vote in an insencere manner. Later Harm Violation is a strong driver for tactical voting. Inconsistency may create circumstances by which a block of voters by voting in certain ways can boost or harm a choice, this vulnerability type is often referred to as an attack, because successful exploitation violates the expectation that all voters have an equal impact on the outcome.


=head3 Arrow's Theorem

Arrows Theorem states that it is impossible to have a system that can resolve Ranked Choice Ballots which meets Later Harm and Condorcet Winner. To extend the notion, if it is impossible to meet two criteria it is truly impossible to meet five. Every method  has a trade off, where it will fail some criteria and fail them to different degrees.


=head3 Popular Ranked Choice Resolution Systems


=head4 Instant Runoff Voting (IRV also known as Alternative Vote)

Seeks a Majority Winner. If there is none the lowest choice is eliminated until there is a Majority Winner or all remaining choices have the same number of votes.

=over

=item *

Easy to Hand Count and Easy to Understand.


=item *

Meets Later Harm.


=item *

Fails Condorcet Winner (but meets Condorcet Loser).


=item *

Fails many Consistency Criteria (The example given for Consistency can happen with IRV). IRV handles clones poorly.


=back


=head4 Borda Count

Scores choices on a ballot based on their position. Borda supporters often disagree about the weighting rule to use in the scoring. Iterative Borda Methods (Baldwin, Nansen) eliminate the lowest choice(s) and recalculate the Borda score ignoring  eliminated choices (if your second choice is eliminated your third choice is promoted).

=over

=item *

Easy to Understand.


=item *

Fails Later Harm.


=item *

Fails Condorcet Winner.


=item *

Inconsistant and vulnerable to manipulation by voters coordinating their votes.


=back


=head4 Condorcet

Technically this family of methods should be called Condorcet Pairwise, because any method that meets both Condorcet Criteria is technically a Condorcet Method. However, in discussion and throughout this software collection the term Condorcet will refer to  methods which uses a Matrix of Wins and Losses derived from direct pairing of choices and seeks to identify a Condorcet Winner.

The basic Condorcet Method will frequently fail to identify a winner. One possibility is a Loop (Condorcet's Paradox) Where A > B, B > C, and C > A. Another possibility is a knot (not an accepted term, but one which will be used in this documentation). A Loop can be considered a tie, and a Knot can be considered something less than a tie. To make Condorcet resolveable a second method is typically used to resolve Loops and Knots.

=over

=item *

Complexity Varies among sub-methods.


=item *

Fails Later Harm.


=item *

Meets both Condorcet Criteria.


=item *

When a Condorcet Winner is present Consistency is met, when a loop is present, this Consistency also applies between the loop and the rest of the choices. Submethods vary in consistency when there is no Condorcet Winner.


=back


=head3 Score Voting Systems

Most Methods for Ranked Choice Ballots can be used for Score Ballots, either directly or by translating the ballots. Score Voting proposals typically implement I<Borda Count>,with a fixed depth of choices. I<STAR>, creates a virtual runoff between the top two I<Borda Count> Choices.

Advocates of Score Voting claim that this Ballot Style it is a better expression of voter preference (which is purely a matter of opinion and cannot be proved or disproved), but it does create more potential for ties in the resolution process than RC does (which is a reason to assert RC is better).


=head1 Objective and Motivation

I wanted to be able to evaluate alternative methods for resolving elections and couldn'
t find a flexible enough existing libary in any of the popular general purpose and web development languages: Perl, PHP, Python, Ruby, JavaScript, nor in the newer language Julia (created as an alternative to R and other math languages). More recently I was writing a bylaws proposal to use RCV and found that the existing libraries and services were not only constrained in what options they can provide, but also didn't document them clearly, making it a challenge to have a method described in bylaws where it could be guaranteed hand and machine counts would agree.

The objective is to have a library that can handle any of the myriad variants that one might consider either from a study perspective or what is called for by the elections rules of our entity.


=head1 Basics


=head2 Reading Ballots

The Vote::Count::ReadBallots library provides functionality for reading files from disc. Currently it defines a format for a ballot file and reads that from disk. In the future additional formats may be added.


=head2 Voting Method and Component Modules

The Modules in the space Vote::Count::%Component% provide functionality needed to create a functioning Voting Method. Many of these are consumed as Roles by the Vote::Count object, some such as RankCount and Matrix are not roles and return their own objects.

The Modules in the space Vote::Count::Method::%Something% implement a Voting Method such as IRV. These Modules inherit the parent Vote::Count and all of the Components available to it.

Simpler Methods such as single iteration Borda or Approval can be run directly from the Vote::Count Object.


=head2 Core Object is Vote::Count

The Core Module requires a Ballot Set (which can be obtained from ReadBallots). Optionally an Active Set can be passed as at creation.

 
   my $Election = Vote::Count->new(
       BallotSet => read_ballots( 'ballotfile'), # imported from ReadBallots
       ActiveSet => { 'A' => 1, 'B' => 1, 'C' => 1 }, # Optional
   );



=head3 Active Sets

Active sets are typically represnted as a Hash Reference where the keys represent the active choices, the values are ignored. The VoteCount Object contains an Active Set which can be Accessed or set via the ->Active() method. Most Components will take an argument for $activeset or default to the current Active set of the Vote::Count object, which will default to the Choices defined in the BallotSet.


=head2 Components


=head3 Consumed As Roles By Vote::Count

=over

=item *

L<Vote::Count::Approval|https://metacpan.org/pod/Vote::Count::Approval>


=item *

L<Vote::Count::Borda|https://metacpan.org/pod/Vote::Count::Borda>


=item *

L<Vote::Count::Floor|https://metacpan.org/pod/Vote::Count::Floor>


=item *

L<Vote::Count::TopCount|https://metacpan.org/pod/Vote::Count::TopCount>


=back


=head3 Return Their Own Objects

  I< L<Vote::Count::Matrix|https://metacpan.org/pod/Vote::Count::Matrix>
  > L<Vote::Count::RankCount|https://metacpan.org/pod/Vote::Count::RankCount>

=cut

#buildpod

#FOOTER

=pod

BUG TRACKER

L<https://github.com/brainbuz/Vote-Count/issues>

AUTHOR

John Karr (BRAINBUZ) brainbuz@cpan.org

CONTRIBUTORS

Copyright 2019 by John Karr (BRAINBUZ) brainbuz@cpan.org.

LICENSE

This module is released under the GNU Public License Version 3. See license file for details. For more information on this license visit L<http://fsf.org>.

=cut