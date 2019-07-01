package Vote::Count::ReadBallots;

use 5.028;
use feature qw/postderef signatures/;
# use strict;
# use warnings;
no warnings qw/experimental/;
use Path::Tiny;
use Carp;
use Data::Dumper;
use Data::Printer;

our $VERSION='2019.0627';

use Exporter::Easy (
       OK => [ qw( read_ballots ) ],
   );

sub _choices ( $choices ) {
  my %C = ();
  $choices =~ m/^\:CHOICES\:(.*)/;
  for my $choice ( split /:/, $1 ) {
    $C{$choice} = 1;
  }
  return \%C;
}

sub read_ballots( $filename ) {
  my %data = (
    'choices' => undef, 'ballots' => {}, 'options' => { 'rcv' => 1 } );
  for my $line_raw ( path($filename)->lines ) {
    chomp $line_raw;
    if ( $line_raw =~ m/^\:CHOICES\:/ ) {
      if ( $data{'choices'} ) {
        croak("File $filename redefines CHOICES \n$line_raw\n");
      }
      else { $data{'choices'} = _choices($line_raw); }
      next;
    }
    my $line = $line_raw;
    next unless ( $line =~ /\w/ );
    $line =~ s/(\d+)\://;
    my $numbals = $1 ? $1 : 1;
    if ( $data{'ballots'}{$line} ) {
      $data{'ballots'}{$line}{'count'} =
        $data{'ballots'}{$line}{'count'} + $numbals;
    }
    else {
      my @votes = ();
      for my $choice ( split( /:/, $line ) ) {
        unless ( $data{'choices'}{$choice} ) {
          die "Choice: $choice is not in defined choice list: "
            . join( ", ", keys( $data{'choices'}->%* ) ) . "\n";
        }
        push @votes, $choice;
      }
      $data{'ballots'}{$line}{'count'} = $numbals;
      $data{'ballots'}{$line}{'votes'} = \@votes;
    }
  }
  return \%data ;
}







1;