# This file is generated by Dist::Zilla::Plugin::CPANFile v6.027
# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "Carp" => "0";
requires "Cpanel::JSON::XS" => "4.32";
requires "Data::Dumper" => "0";
requires "Data::Printer" => "0";
requires "Exporter" => "0";
requires "Exporter::Easy" => "0";
requires "List::Util" => "1.63";
requires "Math::BigInt" => "1.999837";
requires "Math::BigInt::GMP" => "1.6005";
requires "Math::BigRat" => "0.2624";
requires "Mojo::Template" => "0";
requires "Moose" => "0";
requires "Moose::Role" => "0";
requires "MooseX::StrictConstructor" => "0";
requires "Path::Tiny" => "0.130";
requires "Ref::Util" => "0.204";
requires "Sort::Hash" => "0";
requires "Storable" => "3.25";
requires "String::TtyLength" => "0.02";
requires "Test2::API" => "0";
requires "Time::Piece" => "0";
requires "Try::Tiny" => "0";
requires "YAML::XS" => "0";
requires "base" => "0";
requires "feature" => "0";
requires "namespace::autoclean" => "0";
requires "parent" => "0";
requires "perl" => "5.024";
requires "strict" => "0";
requires "utf8" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "Carp::Always" => "0";
  requires "File::Temp" => "0";
  requires "JSON::MaybeXS" => "0";
  requires "Test2::Bundle::More" => "0";
  requires "Test2::Tools::Class" => "0";
  requires "Test2::Tools::LoadModule" => "0.008";
  requires "Test2::Tools::Exception" => "0";
  requires "Test2::Tools::Warnings" => "0";
  requires "Test2::V0" => "0";
  requires "Test::Exception" => "0";
  requires "Test::Fatal" => "0";
  requires "Test::More" => "0";
  requires "lib" => "0";
  requires "ok" => "0";
  requires "perl" => "5.024";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "perl" => "5.024";
};

on 'develop' => sub {
  requires "Test2::Bundle::More" => "0";
  requires "Test2::Tools::Exception" => "0";
  requires "Test2::Tools::Warnings" => "0";
  requires "Test2::V0" => "0";
  requires "Test::Exception" => "0";
  requires "Test::Pod" => "0";
};
