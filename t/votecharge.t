#!/usr/bin/env perl

use 5.022;

# Using Test2, important to specify which version of Test2
# since later versions may break things.
use Test2::V0;
use Test2::Bundle::More;
use Test::Exception;
# use JSON::MaybeXS qw/encode_json/;
# use YAML::XS;
use feature qw /postderef signatures/;
no warnings 'experimental';
# use Path::Tiny;
use Try::Tiny;
use Vote::Count::VoteCharge;
use Vote::Count::ReadBallots 'read_ballots', 'read_range_ballots';
use Test2::Tools::Exception qw/dies lives/;
use Test2::Tools::Warnings qw/warns warning warnings no_warnings/;
use Data::Dumper;

subtest '_setTieBreaks' => sub {
  my $A = Vote::Count::VoteCharge->new(
    Seats     => 5,
    VoteValue => 100,
    BallotSet => read_ballots('t/data/data1.txt')
  );
  like(
    $A->logv(),
    qr/TieBreakMethod is undefined, setting to grandjunction/,
    "Logged: TieBreakMethod is undefined, setting to grandjunction"
  );
  note(
    'this subtest is just for coverage, but did find error by writing it.');
  my $B = Vote::Count::VoteCharge->new(
    BallotSet      => read_ballots('t/data/data1.txt'),
    Seats          => 2,
    VoteValue      => 1000000,
    TieBreakMethod => 'grandjunction',
    PrecedenceFile => 't/data/tiebreakerprecedence1.txt',
  );
  is( $B->TieBreakMethod, 'grandjunction', 'correct tiebreaker reported' );
  is(
    $B->PrecedenceFile,
    't/data/tiebreakerprecedence1.txt',
    'correct precedencefile reported'
  );
  my $C = Vote::Count::VoteCharge->new(
    BallotSet      => read_ballots('t/data/data1.txt'),
    TieBreakMethod => 'precedence',
    Seats          => 4,
  );
  is( $C->TieBreakMethod, 'precedence', 'correct tiebreaker reported' );
  is( $C->PrecedenceFile, '/tmp/precedence.txt',
    'precedencefile set when missing' );
};

subtest '_inits' => sub {
  my $D = Vote::Count::VoteCharge->new(
    Seats     => 4,
    VoteValue => 1000,
    BallotSet => read_ballots('t/data/data1.txt')
  );
  is( $D->BallotSet()->{ballots}{'MINTCHIP'}{'votevalue'},
    1000, 'init correctly set votevalue for a choice' );
  my $DExpect = {
    'STRAWBERRY' => 1000,
    'PISTACHIO'  => 1000,
    'VANILLA'    => 5000,
    'CHOCOLATE'  => 3000,
    'CARAMEL'    => 1000,
    'MINTCHIP'   => 7000,
    'ROCKYROAD'  => 1000,
    'RUMRAISIN'  => 1000
  };
  my $APV = $D->Approval->RawCount();
  is_deeply( $APV, $DExpect,
    'Use Approval to show correct weights were set' );
  my $DX2 = {};
  for my $k ( keys $DExpect->%* ) {
    $DX2->{$k} = { 'state' => 'hopeful', 'votes' => 0 };
  }
  is_deeply( $D->GetChoiceStatus(), $DX2, 'Inited states and votes' );
  $D->SetChoiceStatus( 'CARAMEL',   { state => 'withdrawn' } );
  $D->SetChoiceStatus( 'ROCKYROAD', { state => 'suspended', votes => 12 } );
  is_deeply(
    $D->GetChoiceStatus('CARAMEL'),
    { state => 'withdrawn', votes => 0 },
    'changed choice status for a choice'
  );
  is_deeply(
    $D->GetChoiceStatus('ROCKYROAD'),
    { state => 'suspended', votes => 12 },
    'changed both status status values for a choice'
  );
  $D->Defeat('STRAWBERRY');
  is_deeply(
    $D->GetChoiceStatus('STRAWBERRY'),
    { state => 'defeated', votes => 0 },
    'Defeated a choice'
  );
  undef $D;
  like(
    dies {
      Vote::Count::VoteCharge->new(
        Seats     => 4,
        BallotSet => read_range_ballots('t/data/tennessee.range.json')
      );
    },
    qr/only supports rcv/,
    "Attempt to use range ballots was fatal."
  );

};

subtest 'Charge' => sub {
  my $E = Vote::Count::VoteCharge->new(
    Seats     => 3,
    VoteValue => 1000,
    BallotSet => read_ballots( 't/data/data1.txt', )
  );

  # These 2 need to be done before every new Charge.
  $E->ResetVoteValue();    # undo partial charging from previous.
  $E->TopCount();          # init topcounts.
  like(
    dies { $E->Charge( 'VANILLA', 3000, 1 ) },
    qr/undercharge error/,
    "UnderCharge Error"
  );
  $E->ResetVoteValue();    # undo partial charging from previous.
  $E->TopCount();          # init topcounts.
  my $E1 = $E->Charge( 'MINTCHIP', 3000, 1000 );
  note('checking the return from the first charge attempt to E');
  is( $E1->{choice},   'MINTCHIP', '...the choice is included' );
  is( $E1->{surplus},  2000,       '...the surplus is correct' );
  is( $E1->{cntchrgd}, 5,          '...number of ballots charged' );
  is( $E1->{quota}, 3000, '...quota that was provided is in return' );
  is_deeply(
    [ sort( $E1->{ballotschrgd}->@* ) ],
    [ 'MINTCHIP', 'MINTCHIP:CARAMEL:RUMRAISIN' ],
    '...list of ballots that were charged'
  );
  is( $E->GetChoiceStatus('MINTCHIP')->{'votes'},
    5000, '...choice_status has updated votes' );
};

subtest 'Look at the Charges on some Ballots' => sub {
  my $B = Vote::Count::VoteCharge->new(
    Seats     => 5,
    VoteValue => 1000,
    BallotSet => read_ballots( 't/data/biggerset1.txt', )
  );
  $B->TopCount();
  my $B1 = $B->Charge( 'VANILLA', 40000, 500 );
  $B->Elect('VANILLA');
  $B->TopCount();
  $B1 = $B->Charge( 'CHOCOLATE', .5 * 40000, 500 );
  $B->Elect('CHOCOLATE');
  $B->TopCount();
  $B1 = $B->Charge( 'MINTCHIP', 40000, 750 );
  $B->Elect('MINTCHIP');
  $B->TopCount();
  $B1 = $B->Charge( 'CARAMEL', 40000, 0 );
  $B->Elect('CARAMEL');
  $B->TopCount();
  my %Ballots = $B->GetBallots()->%*;
  is_deeply(
    $Ballots{'VANILLA:CHOCOLATE:STRAWBERRY'}->{charged},
    { VANILLA => 500, CHOCOLATE => 500 },
    'look at a split'
  );
  is( $Ballots{'VANILLA:CHOCOLATE:STRAWBERRY'}->{votevalue},
    0, 'this ballot has no value left' );
  is_deeply(
    $Ballots{'MINTCHIP'}->{charged},
    { MINTCHIP => 750 },
    'look at another split'
  );
  is( $Ballots{'MINTCHIP'}->{votevalue},
    250, 'this ballot has some value left' );
  is_deeply(
    $Ballots{'MINTCHIP:CARAMEL:RUMRAISIN'}->{charged},
    { MINTCHIP => 750, CARAMEL => 250 },
    'look at a split with below quota choice'
  );
  is( $Ballots{'MINTCHIP:CARAMEL:RUMRAISIN'}->{votevalue},
    0, 'this ballot can have no value left' );
  is_deeply(
    $Ballots{'VANILLA'}->{charged},
    { VANILLA => 500 },
    'look at one with no split'
  );
  is( $Ballots{'VANILLA'}->{votevalue},
    500, 'this ballot has half value left' );
};

subtest 'Elect, Defeat, et al' => sub {
  my $F = Vote::Count::VoteCharge->new(
    Seats     => 3,
    VoteValue => 1000,
    BallotSet => read_ballots( 't/data/data1.txt', )
  );
  is_deeply( [ $F->Elect('VANILLA') ],
    ['VANILLA'], 'returns elected choice in list' );
  is_deeply( [ $F->Pending('RUMRAISIN') ],
    ['RUMRAISIN'], 'set a choice pending' );
  is( $F->GetActive()->{'RUMRAISIN'}, undef, 'Rumraisin is pending and not in Active Set' );
  is_deeply(
    [ $F->Elect('RUMRAISIN') ],
    [ 'VANILLA', 'RUMRAISIN' ],
    'electing second choice returns both in correct order'
  );
  is_deeply(
    [ $F->GetActiveList() ],
    [qw/CARAMEL CHOCOLATE MINTCHIP PISTACHIO ROCKYROAD STRAWBERRY /],
    'Active List no longer contains 2 elected choices'
  );
  is( $F->GetChoiceStatus()->{'RUMRAISIN'}{'state'},
    'elected', 'choice status for a newly elected choice is elected' );
  is( $F->GetChoiceStatus('MINTCHIP')->{'state'},
    'hopeful', 'choice status for an unelected choice is still hopeful' );
  is( $F->Pending(), 0, 'after electing pending choice, pending is empty' );
  is_deeply(
    [ $F->Elected() ],
    [ 'VANILLA', 'RUMRAISIN' ],
    'Elected method Returns current list'
  );
  $F->Defeat('CARAMEL');
  $F->Withdraw('CHOCOLATE');
  is_deeply( [ $F->Suspend('ROCKYROAD') ],
    ['ROCKYROAD'], 'suspending a choice returns suspended list' );
  is_deeply(
    [ $F->GetActiveList() ],
    [qw/MINTCHIP PISTACHIO STRAWBERRY /],
    'Active reduced by Elect, Defeat, Withdraw and Suspend'
  );
  is( $F->GetChoiceStatus('CARAMEL')->{state},
    'defeated', 'Confirm defeat with GetChoiceStatus' );
  is( $F->GetChoiceStatus('CHOCOLATE')->{state},
    'withdrawn', 'Confirm withdrawal with GetChoiceStatus' );
  is( $F->GetChoiceStatus('ROCKYROAD')->{state},
    'suspended', 'Confirm suspension with GetChoiceStatus' );
  $F->Reinstate('ROCKYROAD');
  is( $F->GetChoiceStatus('ROCKYROAD')->{state},
    'hopeful', 'Confirm resinstatement with GetChoiceStatus' );
  $F->Reinstate('CARAMEL');
  is( $F->GetChoiceStatus('CARAMEL')->{state},
    'defeated', 'Confirm that Reinstate will not reactivate a defeated choice' );
  is( $F->GetActive()->{'ROCKYROAD'},
    1, 'confirm reinstated back in active list' );
  $F->Suspend('ROCKYROAD');
  $F->Suspend('PISTACHIO');
  $F->Suspend('STRAWBERRY');
  $F->Suspend('STRAWBERRY')
    ;    # a second time to prove it wont be in list twice.
  is_deeply(
    [ sort( $F->Suspended() ) ],
    [qw/PISTACHIO ROCKYROAD STRAWBERRY/],
    'confirm list of suspended choices'
  );
  $F->Reinstate();
  is( $F->Suspended(), 0,
    'group reinstated choices no longer on suspended list' );
  is( $F->GetChoiceStatus('STRAWBERRY')->{state},
    'hopeful', 'Confirm resinstatement with GetChoiceStatus' );
};

subtest 'VCUpdateActive' => sub {
  my $G = Vote::Count::VoteCharge->new(
    Seats     => 3,
    VoteValue => 1000,
    BallotSet => read_ballots( 't/data/data1.txt', )
  );
  for (qw( PISTACHIO RUMRAISIN STRAWBERRY)) {
    $G->{'choice_status'}->{$_}{'state'} = 'defeated';
  }
  $G->{'choice_status'}->{'ROCKYROAD'}{'state'} = 'withdrawn';
  $G->{'choice_status'}->{'CARAMEL'}{'state'}   = 'withdrawn';
  $G->Suspend('MINTCHIP');
  $G->VCUpdateActive();
  is_deeply(
    $G->GetActive(),
    { VANILLA => 1, CHOCOLATE => 1 },
    'VCUPDATEACTIVE set active list to the two hopeful choices'
  );
  $G->{'choice_status'}->{'MINTCHIP'}{'state'} = 'hopeful';
  $G->{'choice_status'}->{'VANILLA'}{'state'} = 'elected';
  $G->VCUpdateActive();
  is_deeply(
    $G->GetActive(),
    { CHOCOLATE => 1, MINTCHIP => 1 },
    'VCUPDATEACTIVE set active with slightly different list'
  );
  $G->{'choice_status'}->{'CARAMEL'}{'state'} = 'pending';
  $G->{'choice_status'}->{'CHOCOLATE'}{'state'} = 'elected';
  $G->VCUpdateActive();
  is_deeply(
    $G->GetActive(),
    { MINTCHIP => 1, CARAMEL => 1 },
    'VCUPDATEACTIVE set active with a choice pending');
};

done_testing();
