use strict;
use warnings;
use 5.026;
use feature qw /postderef signatures/;

package Vote::Count;
use namespace::autoclean;
use Moose;

use Data::Printer;
use Time::Piece;
use Text::MarkdownTable;

our $VERSION = 0.001;

no warnings 'experimental';

has 'BallotSet' => ( is => 'ro', isa => 'HashRef' );
has 'BallotSetType' => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default =>  'rcv',
);

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
      'Vote::Count::Boorda',
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

=pod

how I'm going to handle various types

Range will have a choice of 2 methods to convert to rcv:
  expande ties by Approval
  Divide ties ie 4 ballots [ a, b ] will split to 2 [ a ] and 2 [ b ]

Won't directly handle Approval

Plurality will be treated as an RCV set where all voters bullet voted.