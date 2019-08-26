use strict;
use warnings;
use 5.022;

use feature qw /postderef signatures/;

package Vote::Count::Log;
use Moose::Role;

no warnings 'experimental';
use Path::Tiny 0.108;
# use Data::Printer;


our $VERSION='0.022';

=head1 NAME

Vote::Count::Log

=head1 VERSION 0.022

=cut

# ABSTRACT: Logging for Vote::Count. Toolkit for vote counting.

=head1 Vote::Count Logging Methods

=head2 LogTo

Sets a path and Naming pattern for writing logs with the WriteLogs method.

  'LogTo' => '/logging_path/election_name'

LogTo will not create a new directory if the directory does not exist.

The default log location is '/tmp/votecount'.

=head2 LogPath

Specifies a Path to the Log Files, unlike LogTo, LogPath will create the Path if it does not exist. 

=head2 LogBaseName 

Sets the Base portion of the logfile names, but only if LogPath is specified. The default value is votecount.

=head2 WriteLogs

Write the logs appending '.brief', '.full', and '.debug' for the three logs where brief is a summary written with the logt (log terse) method, the full transcript log written with logv, and finally the debug log written with logd. Each higher log level captures all events of the lower log levels.

=head1 Logging Events

When logging from your methods, use logt for events that produce a summary, use logv for events that should be in the full transcript such as round counts, and finally debug is for events that may be helpful in debugging but which should not be in the transcript. Events written to logt will be included in the verbose log and all events in the verbose log will be in the debug log. 

=cut

has 'LogTo' => (
  is => 'lazy',
  is => 'rw',
  isa => 'Str',
  builder => '_logsetup',
);

has 'LogPath' => (
  is => 'rw',
  isa => 'Str',
  default => '/tmp',  
);

has 'LogBaseName' => (
  is => 'rw',
  isa => 'Str',
  default => 'votecount'
);

sub _logsetup ( $self ) {
  my $pathBase = $self->{'LogPath'} || '/tmp';
  $pathBase =~ s/\/$|\\$//; # trim \ or / from end.
  unless ( stat $pathBase ) {
    path( $pathBase)->mkpath();
  }
  my $baseName = $self->{'LogBaseName'} || 'votecount' ;
  return "$pathBase/$baseName";
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

sub WriteLog {
  my $self = shift @_;
  my $logroot = $self->LogTo();
  path( "$logroot.brief")->spew( $self->logt() );
  path( "$logroot.full")->spew( $self->logv() );
  path( "$logroot.debug")->spew( $self->logd() );
}


1;

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

