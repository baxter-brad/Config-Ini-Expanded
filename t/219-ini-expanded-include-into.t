#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 4;

use File::Temp qw/ tempfile tempdir /;

use Config::Ini::Expanded;

# get the file parts we'll need:
my $dir = tempdir( CLEANUP => 1 );
my ($fh, $filename) = tempfile( DIR => $dir );
my $root = $1 if $filename =~ s,^(/[^/]+/),,;
my $path = "$root$filename";

my $common_data = <<_end_;
name1 = value1(common_data)
name2 = value2(common_data)
name3 = value3(common_data)
_end_

#---------------------------------------------------------------------
# test control case of no 'into' section

NO_INTO: {

    my $data   = $common_data;
    my $string = <<_end_;
{INCLUDE:$filename}
_end_

    open  $fh, '>', $path or die "Can't open $path: $!";
    print $fh $data;
    close $fh;

    my $ini = Config::Ini::Expanded->new(
        include_root => $root,
        string       => $string,
        );

    is( $ini->as_string(), $data, '{INCLUDE:file} NO_INTO ('.__LINE__.')' );
}

#---------------------------------------------------------------------
# test that the 'into' parm is used for the initial section name
# this isn't really an 'include' operation ... maybe we'll move it

INTO_PARM: {

    my $data   = $common_data;
    my $expect = <<_end_.$common_data;
[general]
_end_

    open  $fh, '>', $path or die "Can't open $path: $!";
    print $fh $data;
    close $fh;

    my $ini = Config::Ini::Expanded->new(
        include_root => $root,
        file         => $path,
        into         => 'general',
        );

    is( $ini->as_string(), $expect, 'INTO_PARM ('.__LINE__.')' );
}

#---------------------------------------------------------------------
# test that the 'into' section is used for the initial section name

INTO_SECTION: {

    my $data   = $common_data;
    my $expect = <<_end_.$common_data;
[general]
_end_

    open  $fh, '>', $path or die "Can't open $path: $!";
    print $fh $data;
    close $fh;

    my $ini = Config::Ini::Expanded->new(
        include_root => $root,
        string       => <<_end_ );
[general]
{INCLUDE:$filename}
_end_

    is( $ini->as_string(), $expect, '{INCLUDE:file} INTO_SECTION ('.__LINE__.')' );
}

#---------------------------------------------------------------------
# to test that an explicit null section overrides the 'into' value
NULL_SECTION: {

    my $data = <<_end_.$common_data;
[]
_end_

    my $expect = <<_end_.$common_data;
[general]

[]
_end_

    open  $fh, '>', $path or die "Can't open $path: $!";
    print $fh $data;
    close $fh;

    my $ini = Config::Ini::Expanded->new(
        include_root => $root,
        string       => <<_end_ );
[general]
{INCLUDE:$filename}
_end_

    is( $ini->as_string(), $expect, '{INCLUDE:file} NULL_SECTION ('.__LINE__.')' );
}

