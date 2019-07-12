#!/usr/bin/env perl

use 5.022;
use feature qw/signatures postderef/;
no warnings qw/experimental uninitialized/;
use utf8::all;
use Try::Tiny;

=pod

=head1 buildpod.pl

This is a utility script for the Vote::Count Distribution.
Method Documentation is being written conventionally as inline POD,
Documentation files are being written in MarkDown. This utility
will convert markdown files to pod files, and insert pod into modules
that have a markdown file. The insertion will be between lines that
have #buildpod comments.

As an added convenience buildpod will read the version from dist.ini and
replace the version strings in modules.

=head1 SYNAPSIS

./buildpod.pl

=cut


# use Carp::Always;
use Carp;
use Path::Tiny;
use Markdown::Pod;;
# use Time::Piece;
# use Time::Moment;
# use Search::Tools::UTF8;
# use Unicode::Normalize;
# use List::Util qw(max);
# use Unicode::Collate::Locale;
# use feature 'unicode_strings';
# use Encode qw (from_to decode_utf8 encode_utf8 decode encode);
# use Cpanel::JSON::XS;    # qw( encode_json decode_json );
use Data::Printer;
# use Data::Dumper;
# use charnames ':full';
# use Unicode::UCD 'charinfo';
# use Test::More;
# use Getopt::Long::Descriptive;

=pod

=head1 buildpod.pl

=head1 SYNOPSIS

=head1 VERSION 2019.0712

=cut

our $VERSION='2019.0712';

sub fix_version ( $text, $version ) {
  $text =~ s/our \$VERSION=.*;/our \$VERSION='$version';/g;
  $text =~ s/=head1 VERSION.*\n/=head1 VERSION $version\n/;
  return $text;
}

sub add_pod ( $text, $md ) {
  my $markerstr = '#buildpod';
  my $num_markers = () = $text =~ /$markerstr/g;
say "Counted Markers: $num_markers";
  if ( $num_markers >2 ) {
    die "There are too many $markerstr markers in the current file\\n"
  }
  my @beforepod = ();
  my @afterpod = ();
  my $aftermarker = 0;
  for my $l ( split /\n/, $text ) {
    if ($aftermarker == $num_markers ) { push @afterpod, $l }
    elsif ($aftermarker == 1 ) {
      $aftermarker++ if $l =~ /$markerstr/;
    } else {
      if ( $l =~ /$markerstr/ ) {
      $aftermarker++ if $l =~ /$markerstr/;
      } else {
        push @beforepod, $l;
      }
    }
  }
  return join( "\n",
    ( @beforepod, $markerstr, $md, $markerstr, @afterpod )
  )
}

my $ex1 = <<'QUOTE' ;
use perl;
our $VERSION='2019.0712';

=pod

=head1 something

=head1 VERSION 1.05

=cut
1;

#buildpod

QUOTE

my $testmd = <<'TESTMD';

# A Title

Some Text.

TESTMD


my $dist = path( './dist.ini')->slurp;
$dist =~ /version\s? =\s?(\d+\.\d+)/;
# @paths = path("/tmp")->children( qr/^foo/ );

my $version = $1;
say $version;
$ex1 = fix_version( $ex1, $version);

say add_pod( $ex1, $testmd );
# say $ex1;
