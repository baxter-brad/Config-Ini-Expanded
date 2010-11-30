#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 5;

use File::Temp qw/ tempfile tempdir /;

use Config::Ini::Expanded;

my $dir = tempdir( CLEANUP => 1 );
my ($fh, $filename) = tempfile( DIR => $dir );

my $root = $1 if $filename =~ s,^(/[^/]+/),,;

my $data = <<_end_;
[section]
name1 = value1
name2 = value2
name3 = value3
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
[section]
{JIT:$filename}
_end_

    my $val = $ini->get( section => 'name1' );  # triggers the include
    is( $val, 'value1', '{JIT:ok file} ('.__LINE__.')' );

    is( $ini->as_string(), $data, '{JIT:ok file} ('.__LINE__.')' );

}

#---------------------------------------------------------------------
NO_INCLUDE_ROOT: {

    eval {
        my $ini = Config::Ini::Expanded->new(
            string       => <<_end_ );
[section]
{JIT:$root$filename}
_end_

        $ini->get( section => 'dummy' );  # triggers the include
    };

    ok( $@ =~ /^JIT not allowed/, 'JIT not allowed ('.__LINE__.')' );

}

#---------------------------------------------------------------------
INCLUDE_ROOT_IS_ROOT: {

    eval {
        my $ini = Config::Ini::Expanded->new(
            include_root => '/',
            string       => <<_end_ );
[section]
{JIT:$filename}
_end_

        $ini->get( section => 'dummy' );  # triggers the include
    };

    ok( $@ =~ /^JIT not allowed/, 'JIT not allowed ('.__LINE__.')' );

}

#---------------------------------------------------------------------
ATTEMPT_TO_CD_UP: {

    eval {
        my $ini = Config::Ini::Expanded->new(
            include_root => $root,
            string       => <<_end_ );
[section]
{JIT:../$filename}
_end_

        $ini->get( section => 'dummy' );  # triggers the include
    };

    ok( $@ =~ /^JIT not allowed/, 'JIT not allowed ('.__LINE__.')' );

}

