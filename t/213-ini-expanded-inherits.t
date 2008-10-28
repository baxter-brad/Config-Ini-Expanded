#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 28;

use Config::Ini::Expanded;

my $data = do{ local $/; <DATA> };

my $ini1 = Config::Ini::Expanded->new( string => <<_end_ );
[section]
name1 = value1(ini1)
name2 = value2(ini1)
name3 = value3(ini1)
_end_

$ini1->set_var(
    var1 => 'var1(ini1)',
    var2 => 'var2(ini1)',
    var3 => 'var3(ini1)',
    );

my $ini2 = Config::Ini::Expanded->new(
    inherits => [$ini1],
    string => <<_end_ );
[section]
name2 = value2(ini2)
_end_

$ini2->set_var(
    var2 => 'var2(ini2)',
    );

my $ini3 = Config::Ini::Expanded->new(
    inherits => [$ini2],
    string => <<_end_ );
[section]
name3 = value3(ini3)
_end_

$ini3->set_var(
    var3 => 'var3(ini3)',
    );

my $ini4 = Config::Ini::Expanded->new(
    inherits => [$ini2,$ini1],
    string => <<_end_ );
[section]
name4 = value4(ini4)
_end_

$ini4->set_var(
    var4 => 'var4(ini4)',
    );

my $ini5 = Config::Ini::Expanded->new(
    inherits => [$ini4,$ini3,$ini2,$ini1],
    string => <<_end_ );
[section]
# will inherit during autointerpolation
# (because name1 and name2 don't exist yet)
name1 = <<":chomp"
{INI:section:name1}:{INI:section:name2}:{INI:section:name3}:{INI:section:name4}
<<
name2 = <<':chomp'
{INI:section:name3}:{INI:section:name4}
<<
_end_

is( $ini1->get( xyz=>'abc' ),       undef,          'get()     ('.__LINE__.')' );
is( $ini1->get( section=>'abc' ),   undef,          'get()     ('.__LINE__.')' );
is( $ini1->get( section=>'name1' ), 'value1(ini1)', 'get()     ('.__LINE__.')' );
is( $ini1->get_var( 'var1' ),       'var1(ini1)',   'get_var() ('.__LINE__.')' );
is( $ini2->get( xyz=>'abc' ),       undef,          'get()     ('.__LINE__.')' );
is( $ini2->get( section=>'abc' ),   undef,          'get()     ('.__LINE__.')' );
is( $ini2->get( section=>'name1' ), 'value1(ini1)', 'get()     ('.__LINE__.')' );
is( $ini2->get( section=>'name2' ), 'value2(ini2)', 'get()     ('.__LINE__.')' );
is( $ini2->get_var( 'var1' ),       'var1(ini1)',   'get_var() ('.__LINE__.')' );
is( $ini2->get_var( 'var2' ),       'var2(ini2)',   'get_var() ('.__LINE__.')' );
is( $ini3->get( xyz=>'abc' ),       undef,          'get()     ('.__LINE__.')' );
is( $ini3->get( section=>'abc' ),   undef,          'get()     ('.__LINE__.')' );
is( $ini3->get( section=>'name1' ), 'value1(ini1)', 'get()     ('.__LINE__.')' );
is( $ini3->get( section=>'name2' ), 'value2(ini2)', 'get()     ('.__LINE__.')' );
is( $ini3->get( section=>'name3' ), 'value3(ini3)', 'get()     ('.__LINE__.')' );
is( $ini3->get_var( 'var1' ),       'var1(ini1)',   'get_var() ('.__LINE__.')' );
is( $ini3->get_var( 'var2' ),       'var2(ini2)',   'get_var() ('.__LINE__.')' );
is( $ini3->get_var( 'var3' ),       'var3(ini3)',   'get_var() ('.__LINE__.')' );
is( $ini3->get( xyz=>'abc' ),       undef,          'get()     ('.__LINE__.')' );
is( $ini3->get( section=>'abc' ),   undef,          'get()     ('.__LINE__.')' );
is( $ini4->get( section=>'name1' ), 'value1(ini1)', 'get()     ('.__LINE__.')' );
is( $ini4->get( section=>'name2' ), 'value2(ini2)', 'get()     ('.__LINE__.')' );
is( $ini4->get( section=>'name3' ), 'value3(ini1)', 'get()     ('.__LINE__.')' );
is( $ini4->get_var( 'var1' ),       'var1(ini1)',   'get_var() ('.__LINE__.')' );
is( $ini4->get_var( 'var2' ),       'var2(ini2)',   'get_var() ('.__LINE__.')' );
is( $ini4->get_var( 'var3' ),       'var3(ini1)',   'get_var() ('.__LINE__.')' );
is( $ini5->get( section=>'name1' ),
    'value1(ini1):value2(ini2):value3(ini1):value4(ini4)',
    'get() (interpolated) ('.__LINE__.')' );
is( $ini5->get_expanded( section=>'name2' ),
    'value3(ini1):value4(ini4)',
    'get_expanded() ('.__LINE__.')' );

__END__
