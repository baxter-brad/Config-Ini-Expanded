#!/usr/local/bin/perl
use warnings;
use strict;

use Config::Ini::Expanded;

#---------------------------------------------------------------------
# Setting up ...

my $ini;
my $num_tests;

BEGIN {
    my $ini_data = <<'_end_ini_';

[to_test]

html = <b>This</b> is a <i>test</i>.

html_loop = <<:json
[ { "data": "<b>This</b> is a <i>test</i>." } ]
<<

url = This is a test.

url_loop = <<:json
[ { "data": "This is a test." } ]
<<

[tests]

cmt = {INI:...:escape_html(...)}
tmpl = {INI:to_test:escape_html(html)}
out = &lt;b&gt;This&lt;/b&gt; is a &lt;i&gt;test&lt;/i&gt;.

cmt = {INI:...:escape_url(...)}
tmpl = {INI:to_test:escape_url(url)}
out = This+is+a+test.

cmt = {VAR:escape_html(...)}
tmpl = {VAR:escape_html(html)}
out = &lt;b&gt;This&lt;/b&gt; is a &lt;i&gt;test&lt;/i&gt;.

cmt = {VAR:escape_url(...)}
tmpl = {VAR:escape_url(url)}
out = This+is+a+test.

cmt = {LVAR:escape_html(...)}
tmpl = {LOOP:html}{LVAR:escape_html(data)}{END_LOOP:html}
out = &lt;b&gt;This&lt;/b&gt; is a &lt;i&gt;test&lt;/i&gt;.

cmt = {LVAR:escape_url(...)}
tmpl = {LOOP:url}{LVAR:escape_url(data)}{END_LOOP:url}
out = This+is+a+test.

#---------------------------------------------------------------------
_end_ini_

    $ini = Config::Ini::Expanded->new( string => $ini_data );

    # calculate how many tests for Test::More
    my @tests = $ini->get( tests => 'tmpl' );
    $num_tests = @tests;

}

BEGIN {  # Yup, we need another BEGIN block ...
    use Test::More tests => ( $num_tests * 2 );
}

#---------------------------------------------------------------------
# Testing ...

# "silly" subs for testing
$ini->callbacks( {
    escape_html => sub { my($s)=@_; for($s){s/</&lt;/g;s/>/&gt;/g} $s },
    escape_url  => sub { my($s)=@_; for($s){s/ /+/g;s/&/&amp;/g  } $s },
} );

$ini->set_var(
    html => $ini->get( to_test => 'html' ),
    url  => $ini->get( to_test => 'url'  ),
);

$ini->set_loop(
    html => $ini->get( to_test => 'html_loop' ),
    url  => $ini->get( to_test => 'url_loop'  ),
);

for ( 1 .. $num_tests ) {
    my $occur   = $_ - 1;
    my $output  = $ini->get_expanded( tests => 'tmpl', $occur );
    my $wanted  = $ini->get(          tests => 'out',  $occur );
    my $comment = $ini->get(          tests => 'cmt',  $occur );

    is( $output, $wanted, $comment );
}

for ( 1 .. $num_tests ) {
    my $occur   = $_ - 1;
    my $output  = $ini->get_interpolated( tests => 'tmpl', $occur );
    my $wanted  = $ini->get(              tests => 'out',  $occur );
    my $comment = $ini->get(              tests => 'cmt',  $occur );

    is( $output, $wanted, $comment );
}

__END__
