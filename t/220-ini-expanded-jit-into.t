#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 10;

use File::Temp qw/ tempfile tempdir /;

use Config::Ini::Expanded;

my $dir = tempdir( CLEANUP => 1 );
my ($fh, $filename) = tempfile( DIR => $dir );
my $root = $1 if $filename =~ s,^(/[^/]+/),,;
my $path = $root.$filename;

my $common_data = <<_end_;
name1 = value1
name2 = value2
name3 = value3

[section2]
name2.1 = value2.1
_end_

#---------------------------------------------------------------------
# to test the control case of no 'into' section

NO_INTO: {

    my $data   = $common_data;
    my $string = <<_end_;
{JIT:$filename}
_end_

    open  $fh, '>', $path or die "Can't open $path: $!";
    print $fh $data;
    close $fh;

    my $ini = Config::Ini::Expanded->new(
        include_root => $root,
        string       => $string,
        );

    # note that we're asking for name1 in the null section ...
    my $val = $ini->get( 'name1' );  # triggers the include
    is( $val, 'value1', '{JIT:file} ('.__LINE__.')' );

    is( $ini->as_string(), $data, '{JIT:file} ('.__LINE__.')' );

}

#---------------------------------------------------------------------
# to test jit including with 'into' section

INTO_SECTION: {

    my $data   = $common_data;
    my $expect = <<_end_.$common_data;
[section]
_end_
    my $string = <<_end_;
[section]
{JIT:$filename}
_end_

    open  $fh, '>', $path or die "Can't open $path: $!";
    print $fh $data;
    close $fh;

    my $ini = Config::Ini::Expanded->new(
        include_root => $root,
        string       => $string,
        );

    my $val = $ini->get( section => 'name1' );  # triggers the include
    is( $val, 'value1', '{JIT:file} ('.__LINE__.')' );

    is( $ini->as_string(), $expect, '{JIT:file} ('.__LINE__.')' );

}

#---------------------------------------------------------------------
# to test jit including with explicit null section

NULL_SECTION: {

    my $data = <<_end_.$common_data;
[]
_end_
    my $expect = <<_end_.$common_data;
[section]

[]
_end_
    my $string = <<_end_;
[section]
{JIT:$filename}
_end_

    open  $fh, '>', $path or die "Can't open $path: $!";
    print $fh $data;
    close $fh;

    my $ini = Config::Ini::Expanded->new(
        include_root => $root,
        string       => $string,
        );

    my $val = $ini->get( section => 'name1' );       # triggers the include
    is( $val, undef, '{JIT:file} ('.__LINE__.')' );  # but name1 not in [section]

    $val = $ini->get( 'name1' );  # get from null section
    is( $val, 'value1', '{JIT:file} ('.__LINE__.')' );

    is( $ini->as_string(), $expect, '{JIT:file} ('.__LINE__.')' );

}

#---------------------------------------------------------------------
# to test inheritance

INHERITS: {

    my $data   = $common_data;
    my $expect = <<_end_.$common_data;
[section]
_end_
    my $string = <<_end_;
[section]
{JIT:$filename}
_end_

    open  $fh, '>', $path or die "Can't open $path: $!";
    print $fh $data;
    close $fh;

    my $ini1 = Config::Ini::Expanded->new( $path );
    my $ini2 = Config::Ini::Expanded->new(
        include_root => $root,
        inherits     => [ $ini1 ],
        string       => $string,
        );

    my $val = $ini2->get( section2 => 'name2.1' );  # triggers inheritance
    is( $val, 'value2.1', '{JIT:file} inheritance okay ('.__LINE__.')' );

    $val = $ini2->get( section => 'name1' );  # triggers the include
    is( $val, 'value1', '{JIT:file} include okay ('.__LINE__.')' );

    is( $ini2->as_string(), $expect, '{JIT:file} INHERITS ('.__LINE__.')' );
}

