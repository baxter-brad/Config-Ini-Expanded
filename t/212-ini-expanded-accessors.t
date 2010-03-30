#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 43;

use Config::Ini::Expanded;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Expanded->new( string => $data );

is( defined $ini->file(),     '',         'file() ('.__LINE__.')' );
is( $ini->file( 'acme.ini' ), 'acme.ini', 'file() ('.__LINE__.')' );
is( $ini->file(),             'acme.ini', 'file() ('.__LINE__.')' );

is( $ini->keep_comments(),  0, 'keep_comments() ('.__LINE__.')' );
is( $ini->keep_comments(0), 0, 'keep_comments() ('.__LINE__.')' );
is( $ini->keep_comments(),  0, 'keep_comments() ('.__LINE__.')' );

is( $ini->heredoc_style(),     '<<', 'heredoc_style() ('.__LINE__.')' );
is( $ini->heredoc_style('{}'), '{}', 'heredoc_style() ('.__LINE__.')' );
is( $ini->heredoc_style(),     '{}', 'heredoc_style() ('.__LINE__.')' );

is( $ini->encoding(),       '',     'encoding() ('.__LINE__.')' );
is( $ini->encoding('utf8'), 'utf8', 'encoding() ('.__LINE__.')' );
is( $ini->encoding(),       'utf8', 'encoding() ('.__LINE__.')' );

is( $ini->interpolates(),  1, 'interpolates() ('.__LINE__.')' );
is( $ini->interpolates(0), 0, 'interpolates() ('.__LINE__.')' );
is( $ini->interpolates(),  0, 'interpolates() ('.__LINE__.')' );

is( $ini->expands(),  0, 'expands() ('.__LINE__.')' );
is( $ini->expands(1), 1, 'expands() ('.__LINE__.')' );
is( $ini->expands(),  1, 'expands() ('.__LINE__.')' );

is( $ini->include_root(),       '',     'include_root() ('.__LINE__.')' );
is( $ini->include_root('acme'), 'acme', 'include_root() ('.__LINE__.')' );
is( $ini->include_root(),       'acme', 'include_root() ('.__LINE__.')' );

is( $ini->inherits(),  '', 'inherits() ('.__LINE__.')' );
is( $ini->inherits(1), 1,  'inherits() ('.__LINE__.')' );
is( $ini->inherits(),  1,  'inherits() ('.__LINE__.')' );

is( $ini->no_inherit(),  '', 'no_inherit() ('.__LINE__.')' );
is( $ini->no_inherit(1), 1,  'no_inherit() ('.__LINE__.')' );
is( $ini->no_inherit(),  1,  'no_inherit() ('.__LINE__.')' );

is( $ini->no_override(),  '', 'no_override() ('.__LINE__.')' );
is( $ini->no_override(1), 1,  'no_override() ('.__LINE__.')' );
is( $ini->no_override(),  1,  'no_override() ('.__LINE__.')' );

is( defined $ini->filter(),  '',     'filter() ('.__LINE__.')' );
is( ref $ini->filter(sub{}), 'CODE', 'filter() ('.__LINE__.')' );
is( ref $ini->filter(),      'CODE', 'filter() ('.__LINE__.')' );

is( defined $ini->callbacks(), '',     'callbacks() ('.__LINE__.')' );
is( ref $ini->callbacks({}),   'HASH', 'callbacks() ('.__LINE__.')' );
is( ref $ini->callbacks(),     'HASH', 'callbacks() ('.__LINE__.')' );

is( $ini->loop_limit(),   10, 'loop_limit() ('.__LINE__.')' );
is( $ini->loop_limit(20), 20, 'loop_limit() ('.__LINE__.')' );
is( $ini->loop_limit(),   20, 'loop_limit() ('.__LINE__.')' );

is( $ini->size_limit(),     1_000_000, 'size_limit() ('.__LINE__.')' );
is( $ini->size_limit(1000), 1000,      'size_limit() ('.__LINE__.')' );
is( $ini->size_limit(),     1000,      'size_limit() ('.__LINE__.')' );

eval { $ini->you_dont_know_me(1); };
ok( $@ =~ /Undefined: you_dont_know_me()/, 'undefined sub()' );

__DATA__
[section]
name = value

