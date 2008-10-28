#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 8;

use File::Temp qw/ tempfile tempdir /;

use Config::Ini::Expanded;

my $dir = tempdir( CLEANUP => 1 );
my ($fh, $filename) = tempfile( DIR => $dir );

my $root = $1 if $filename =~ s,^(/[^/]+/),,;

my $data = <<_end_;
[section]
name1 = value1(ini1)
name2 = value2(ini1)
name3 = value3(ini1)
_end_

open $fh, '>', "$root$filename" or
    die "Can't open $root$filename: $!";
print {$fh} $data;
close $fh;

#---------------------------------------------------------------------
OK_USAGE: {
    my $ini = Config::Ini::Expanded->new(
        include_root => $root,
        string       => <<_end_ );
    {INCLUDE:$filename}
_end_

    is( $ini->as_string(), $data, '{INCLUDE:...} ('.__LINE__.')' );

    my $string = <<_end_;
[test]
test = {""
$data
}
_end_
    $ini = Config::Ini::Expanded->new(
        include_root => $root,
        string       => <<_end_ );
[test]
test = {""
{FILE:$filename}
}
_end_

    is( $ini->as_string(), $string, '{FILE:...} ('.__LINE__.')' );
}

#---------------------------------------------------------------------
NO_INCLUDE_ROOT: {

    eval {
        my $ini = Config::Ini::Expanded->new(
            string       => <<_end_ );
        {INCLUDE:$root$filename}
_end_
    };
    ok( $@ =~ /^INCLUDE not allowed/, 'INCLUDE not allowed ('.__LINE__.')' );

    eval {
        my $ini = Config::Ini::Expanded->new(
            string       => <<_end_ );
[test]
test = {""
{FILE:$root$filename}
}
_end_
    };
    ok( $@ =~ /^FILE not allowed/, 'FILE not allowed ('.__LINE__.')' );

}

#---------------------------------------------------------------------
INCLUDE_ROOT_IS_ROOT: {

    eval {
        my $ini = Config::Ini::Expanded->new(
            include_root => '/',
            string       => <<_end_ );
        {INCLUDE:tmp/$filename}
_end_
    };
    ok( $@ =~ /^INCLUDE not allowed/, 'INCLUDE not allowed ('.__LINE__.')' );

    eval {
        my $ini = Config::Ini::Expanded->new(
            include_root => '/',
            string       => <<_end_ );
[test]
test = {""
{FILE:tmp/$filename}
}
_end_
    };
    ok( $@ =~ /^FILE not allowed/, 'FILE not allowed ('.__LINE__.')' );

}

#---------------------------------------------------------------------
ATTEMPT_TO_CD_UP: {

    eval {
        my $ini = Config::Ini::Expanded->new(
            include_root => $root,
            string       => <<_end_ );
        {INCLUDE:../$filename}
_end_
    };
    ok( $@ =~ /^INCLUDE not allowed/, 'INCLUDE not allowed ('.__LINE__.')' );

    eval {
        my $ini = Config::Ini::Expanded->new(
            include_root => $root,
            string       => <<_end_ );
[test]
test = {""
{FILE:../$filename}
}
_end_
    };
    ok( $@ =~ /^FILE not allowed/, 'FILE not allowed ('.__LINE__.')' );

}

