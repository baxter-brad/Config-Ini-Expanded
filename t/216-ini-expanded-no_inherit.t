#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 6;

use Config::Ini::Expanded;

# set up ini1 for ini2 to inherit from
my $ini1 = Config::Ini::Expanded->new( string => <<_end_ );
[section]
name1 = value1(ini1)
name2 = value2(ini1)
name3 = value3(ini1)
name4 = value4(ini1)
name5 = value5(ini1)
_end_

# set up ini2 to inherit from ini1
my $ini2 = Config::Ini::Expanded->new(
    inherits => [$ini1],
    no_inherit => { section => { name3 => 1, name5 => 1 }  },
    string => <<_end_ );
[section]
name2 = value2(ini2)
_end_

is( $ini1->get( section=>'name1' ), 'value1(ini1)', 'get()     ('.__LINE__.')' );
is( $ini2->get( section=>'name1' ), 'value1(ini1)', 'get()     ('.__LINE__.')' );
is( $ini2->get( section=>'name2' ), 'value2(ini2)', 'get()     ('.__LINE__.')' );
is( $ini2->get( section=>'name3' ), undef,          'get()     ('.__LINE__.')' );
is( $ini2->get( section=>'name4' ), 'value4(ini1)', 'get()     ('.__LINE__.')' );
is( $ini2->get( section=>'name5' ), undef,          'get()     ('.__LINE__.')' );

__END__
