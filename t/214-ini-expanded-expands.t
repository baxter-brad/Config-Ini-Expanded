#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 1;

use Config::Ini::Expanded;

# This tests the 'expands' attribute.
# On new(), the value of name4 should be
# expanded (because it's in quotes).
# It should become the value of name2,
# then of name1, then of name3, hence:
# value3.
# The values of name1 and name2 are
# not expanded, because they are not
# in quotes.

my $data = <<_end_;
[section1]
name1 = {INI:section3:name3}

[section2]
name2 = {INI:section1:name1}

[section3]
name3 = value3

[section4]
name4 = "{INI:section2:name2}"
_end_

my $want = <<_end_;
[section1]
name1 = {INI:section3:name3}

[section2]
name2 = {INI:section1:name1}

[section3]
name3 = value3

[section4]
name4 = "value3"
_end_

my $ini = Config::Ini::Expanded->new(
    string  => $data,
    expands => 1,
    );

is( $ini->as_string(), $want, 'expands() ('.__LINE__.')' );

