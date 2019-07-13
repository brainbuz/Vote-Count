use strict;
use warnings;
use 5.022;
use feature qw /postderef signatures/;

package Vote::Count::Method::CondorcetDropping;

use namespace::autoclean;
use Moose;
extends 'Vote::Count';
# Brings the main Vote::Count Object in along with
# Topcount and other methods.
# with 'Vote::Count';
# with 'Vote::Count::Matrix';

our $VERSION='0.002';

=head1 NAME

Vote::Count::Method::CondorcetDropping

=head1 VERSION 0.000

=cut

# ABSTRACT: Methods which use simple dropping rules to resolve a Winnerless Condorcet Matrix.

#buildpod

#buildpod

no warnings 'experimental';
use List::Util qw( min max );

use Vote::Count::Matrix;
# use Try::Tiny;
use Text::Table::Tiny 'generate_markdown_table';
use Data::Printer;
use Data::Dumper;

subtype 'DropRuleName',
    as 'Str',
    where { lc($_) =~ /coderef|boorda|approval|plurality|topcount/ },
    message { "$_ is not one of the defined coderef|boorda|approval|plurality rules, for a custom rule use coderef " };
};

has 'DropStyle' => {
  isa => 'DropRuleName',
  is => 'ro',
  default => 'plurality'
};

has 'DropRule' => {
  isa => 'CodeRef',
  is => 'to',
  builder => '_builddroprule',
}