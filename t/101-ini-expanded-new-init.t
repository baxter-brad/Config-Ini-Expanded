#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 1;
use Data::Dumper;

use Config::Ini::Expanded;

my $data = do{ local $/; <DATA> };

my $ini1 = Config::Ini::Expanded->new( string => $data );
my $dump1 = Dumper $ini1;

my $ini2 = Config::Ini::Expanded->new();
$ini2->init( string => $data );
my $dump2 = Dumper $ini2;

is( $dump1, $dump2, 'init() vs new()' );

__DATA__
# Section 1

[section1]

# Name 1.1
name1.1 = value1.1

# Name 1.2a
name1.2 = value1.2a
# Name 1.2b
name1.2 = value1.2b

# Section 2

[section2]

# Name 2.1

name2.1 = {
value2.1
}
name2.2 = <<:chomp
value2.2
value2.2
<<
name2.3 = {here :join
value2.3
value2.3
}here
name2.4 = <<here :parse(\n)
value2.4
value2.4
<<here
