# This file is generated by Dist::Zilla::Plugin::CPANFile v6.017
# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "Carp" => "0";
requires "Cpanel::JSON::XS" => "4.19";
requires "Data::Dumper" => "0";
requires "Exporter" => "0";
requires "Exporter::Easy" => "0";
requires "JSON::MaybeXS" => "1.004000";
requires "List::Util" => "0";
requires "Math::BigInt::GMP" => "1.6003";
requires "Math::BigRat" => "0";
requires "Mojo::Template" => "0";
requires "Moose" => "0";
requires "Moose::Role" => "0";
requires "MooseX::StrictConstructor" => "0.21";
requires "Path::Tiny" => "0.108";
requires "Ref::Util" => "0.202";
requires "Sort::Hash" => "0";
requires "Storable" => "3.15";
requires "String::TtyLength" => "0.02";
requires "Test2::API" => "0";
requires "Time::Piece" => "0";
requires "Try::Tiny" => "0";
requires "YAML::XS" => "0";
requires "base" => "0";
requires "feature" => "0";
requires "namespace::autoclean" => "0";
requires "parent" => "0";
requires "strict" => "0";
requires "utf8" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "Carp::Always" => "0";
  requires "Data::Printer" => "0";
  requires "File::Temp" => "0";
  requires "Test2::Bundle::More" => "0";
  requires "Test2::Tools::Exception" => "0";
  requires "Test2::Tools::Warnings" => "0";
  requires "Test2::V0" => "0";
  requires "Test::Exception" => "0";
  requires "Test::Fatal" => "0";
  requires "Test::More" => "0";
  requires "lib" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "perl" => "5.024";
};
