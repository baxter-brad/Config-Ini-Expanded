#---------------------------------------------------------------------
package Config::Ini::Expanded::POD;

use 5.008000;
use strict;
use warnings;

#---------------------------------------------------------------------

=begin html

 <style type="text/css">
 @import "http://dbsdev.galib.uga.edu/sitegen/css/sitegen.css";
 body { margin: 1em; }
 </style>

=end html

=head1 NAME

Config::Ini::Expanded - Ini configuration file reading/writing with
template expansion capabilities.

=head1 SYNOPSIS

 use Config::Ini::Expanded;
 
 my $ini = Config::Ini::Expanded->new( 'file.ini' );
 
 # traverse the values
 for my $section ( $ini->get_sections() ) {
     print "$section\n";
 
     for my $name ( $ini->get_names( $section ) ) {
         print "  $name\n";
 
         for my $value ( $ini->get( $section, $name ) ) {
             print "    $value\n";
         }
     }
 }

=head1 VERSION

VERSION: 1.18

=head1 DESCRIPTION

This is an Ini configuration file processor.  This class inherits from
Config::Ini::Edit (and Config::Ini).  It uses those modules as well as
Config::Ini::Quote, Text::ParseWords and JSON;

=head2 Terminology

This document uses the terms I<comment>, I<section>, I<name>, and
I<value> when referring to the following parts of the Ini file syntax:

 # comment
 [section]
 name = value

In particular 'name' is the term used to refer to the named options
within the sections.  This terminology is also reflected in method
names, like C<get_sections()> and C<get_names()>.

=head2 Syntax

=head3 The I<null section>

At the top of an Ini file, before any sections have been explicitly
defined, name/value pairs may be defined.  These are assumed to be in
the 'null section', as if an explicit C<[]> line were present.

 # before any sections are defined,
 # assume section eq '', the "null section"
 name = value
 name: value

This 'null section' concept allows for very simple configuration files,
e.g.,

 title = Hello World
 color: blue
 margin: 0

=head3 Comments

Comments may begin with C<'#'> or C<';'>.

 # comments may begin with # or ;, i.e.,
 ; semicolon is valid comment character

Comments may begin on a separate line or may follow section headings.
Comments may not follow unquoted values.

 # this is a comment
 [section] # this is a comment
 name = value # this is NOT a comment (it is part of the value)

But comments may follow quoted values.

 # comments are allowed after quoted values
 name = 'value' # this is a comment
 name = "value" # this is a comment

=head3 Assignments

Spaces and tabs around the C<'='> and C<':'> assignment characters are
stripped, i.e., they are not included in the name or value.  Use
heredoc syntax to set a value with leading spaces.  Trailing spaces in
values are left intact.

 [section]
 
 # spaces/tabs around '=' are stripped
 # use heredoc to give a value with leading spaces
 # trailing spaces are left intact
 
 name=value
 name= value
 name =value
 name = value
 name    =    value
 
 # colon is valid assignment character, too.
 name:value
 name: value
 name :value
 name : value
 name    :    value

=head3 Heredocs

Heredoc syntax may be used to assign values that span multiple lines.
Heredoc syntax is supported in more ways than just the classic syntax,
as illustrated below.

 # classic heredoc:
 name = <<heredoc
 Heredocs are supported several ways.
 This is the "classic" syntax, using a
 "heredoc tag" to mark the begin and end.
 heredoc
 
 # ... and the following is supported because I kept doing this
 name = <<heredoc
 value
 <<heredoc
 
 # ... and also the following, because often no one cares what it's called
 name = <<
 value
 <<
 
 # ... and finally "block style" (for vi % support)
 name = {
 value
 }
 
 # ... and obscure variations, e.g.,
 name = {heredoc
 value
 heredoc

That is, the heredoc may begin with C<< '<<' >> or C<'{'> with or
without a tag.  And it may then end with C<< '<<' >> or C<'}'> (with or
without a tag, as it began).  When a tag is used, the ending
C<< '<<' >> or C<'}'> is optional.

=head3 Quoted Values

Values may be put in single or double quotes.

Single-quoted values will be parsed literally, except that imbedded
single quotes must be escaped by doubling them, e.g.,

 name = 'The ties that bind.'
 
 $name = $ini->get( section => 'name' );
 # $name eq "The ties that bind."

 name = 'The ''ties'' that ''bind.'''
 
 $name = $ini->get( section => 'name' );
 # $name eq "The 'ties' that 'bind.'"

This uses C<Config::Ini::Quote::parse_single_quoted()>.

Double-quoted values may be parsed a couple of different ways.  By
default, backslash-escaped unprintable characters will be unescaped to
their actual Unicode character.  This includes ascii control characters
like C<\n>, C<\t>, etc., Unicode character codes like C<\N> (Unicode
next line), C<\P> (Unicode paragraph separator), and hex-value escape
sequences like C<\x86> and C<\u263A>.

If the C<':html'> heredoc modifier is used (see Heredoc Modifiers
below), then HTML entities will be decoded (using HTML::Entities) to
their actual Unicode characters.

This uses C<Config::Ini::Quote::parse_double_quoted()>.

See Config::Ini:Quote for more details.

=head3 Heredoc :modifiers

There are several ways to modify the value in a heredoc as the Ini file
is read in (i.e., as the object is initialized):

 :chomp    - chomps the last line
 :join     - chomps every line BUT the last one
 :indented - unindents every line (strips leading whitespace)
 :parse    - splits on newline (and chomps last line)
 :parse(regex) - splits on regex (still chomps last line)
 :slash    - unescapes backslash-escaped characters in double quotes (default)
 :html     - decodes HTML entities in double quotes
 :json     - parses javascript object notation (complex data types)

The C<':parse'> modifier uses C<Text::ParseWords::parse_line()>, so
CSV-like parsing is possible.

The C<':json'> modifier uses the JSON module to parse and dump complex
data types (combinations of hashes, arrays, scalars).  The value of the
heredoc must be valid JavaScript Object Notation.

The C<':slash'> and C<':html'> modifiers are only valid when double
quotes are used (surrounding the heredoc tag and modifiers).  If no
modifiers are given with double quotes, C<':slash'> is the default.

 name = <<"EOT :html"
 vis-&agrave;-vis
 EOT

 name = <<"EOT"
 \tSmiley: \u263A
 EOT

Modifiers may be stacked, e.g., C<< '<<:chomp:join:indented' >> (or
C<< '<<:chomp :join :indented' >>), in any order, but note that
C<':parse'> and C<':json'> are performed last.

 # value is "Line1\nLine2\n"
 name = <<
 Line1
 Line2
 <<
 
 # value is "Line1\nLine2"
 name = <<:chomp
 Line1
 Line2
 <<
 
 # value is "Line1Line2\n"
 name = <<:join
 Line1
 Line2
 <<
 
 # value is "Line1Line2"
 name = <<:chomp:join
 Line1
 Line2
 <<
 
 # value is "  Line1\n  Line2\n"
 name = <<
   Line1
   Line2
 <<
 
 # - indentations do NOT have to be regular to be unindented
 # - any leading spaces/tabs on every line will be stripped
 # - trailing spaces are left intact, as usual
 # value is "Line1\nLine2\n"
 name = <<:indented
   Line1
   Line2
 <<
 
 # modifiers may have spaces between them
 # value is "Line1Line2"
 name = << :chomp :join :indented
   Line1
   Line2
 <<
 
 # ... and should come after a heredoc "tag"
 # value is "Line1Line2"
 name = <<heredoc :chomp :join :indented
   Line1
   Line2
 heredoc

The C<':parse'> modifier splits a single value into multiple values.
It may be given with a regular expression parameter to split on other
than newline (the default).

 # :parse is same as :parse(\n)
 name = <<:parse
 value1
 value2
 <<

... is the same as

 name = value1
 name = value2

... and

 name = <<:parse(/,\s+/)
 "Tom, Dick, and Harry", Fred and Wilma
 <<

... is the same as

 name = Tom, Dick, and Harry
 name = Fred and Wilma

The C<':parse'> modifier chomps only the last line, so include C<'\n'>
if needed.

 # liberal separators
 name = <<:parse([,\s\n]+)
 "Tom, Dick, and Harry" "Fred and Wilma"
 Martha George, 'Hillary and Bill'
 <<

... is the same as,

 name = Tom, Dick, and Harry
 name = Fred and Wilma
 name = Martha
 name = George
 name = Hillary and Bill


As illustrated above, the enclosing C<'/'> characters around the
regular expression are optional.  You may also use matching quotes
instead, e.g., C<:parse('\s')>.

 name = <<:json
 { "a": 1, "b": 2, "c": 3 }
 <<

Given the above C<':json'> example, C<< $ini->get('name') >> should
return a hashref.  Note that we NO LONGER accept bare hash keys.

Modifiers must follow the heredoc characters C<< '<<' >> (or C<'{'>).
If there is a heredoc tag, e.g., C<'EOT'> below, the modifiers should
follow it, too.

 name = <<EOT:json
 { "a": 1, "b": 2, "c": 3 }
 EOT

If you want to use single or double quotes, surround the heredoc tag
and modifiers with the appropriate quotes:

 name = <<'EOT :indented'
     line1
     line2
 EOT

 name = <<"EOT :html"
 vis-&agrave;-vis
 EOT

If no heredoc tag is used, put the quotes around the modifiers.

 name = <<":html"
 vis-&agrave;-vis
 <<

If no modifiers either, just use empty quotes.

 name = <<""
 vis-\xE0-vis
 <<

Comments are allowed on the assignment line if quotes are used.

 name = <<'EOT :indented' # this is a comment
     line1
     line2
 EOT

But note:

 name = <<EOT
 'Line1' # this is NOT a comment
 EOT

=head3 Quotes in Heredocs

In heredocs, embedded single and double quotes do not have to be
(and should not be) escaped.  In other words leave single quotes as
C<"'"> (not C<"''">), and leave double quotes as C<'"'> (not C<'\"'>).

 name = <<'EOT :indented'
     'line1'
     'line2'
 EOT
 
 # $name eq "'line1'\n'line2'\n"
 $name = $ini->get( 'name' );

 name = <<"EOT :html"
 "vis-&agrave;-vis"
 EOT
 
 # $name eq qq{"vis-\xE0-vis"}
 $name = $ini->get( 'name' );

=head1 GLOBAL SETTINGS

The global settings below are stored in the object during C<init()>.
So if the global settings are subsequently changed, any existing
objects will not be affected.

=head2 $Config::Ini::Expanded::keep_comments

This boolean value will determine if comments are kept when an Ini file
is loaded or when an Ini object is written out using C<as_string()>.
The default is false -- comments are not kept.  The rational is this:
Unlike the Config::Ini::Edit module, the C<Expanded> module is not
indented primarily to rewrite Ini files, so it is more likely that
comments aren't needed in the object.

=head2 $Config::Ini::Expanded::heredoc_style

This string can be one of C<< '<<' >>, C<< '<<<<' >>, C<'{'>, or
C<'{}'> (default is C<< '<<' >>).  This determines the default heredoc
style when the object is written out using C<as_string()>.  If a value
was read in originally from a heredoc, it will be written out using
that heredoc style, not this default style.  The above values
correspond respectively to the following styles.

 # '<<'
 name = <<EOT
 Hey
 EOT

 # '<<<<'
 name = <<EOT
 Hey
 <<EOT

 # '{'
 name = {EOT
 Hey
 EOT

 # '{}'
 name = {EOT
 Hey
 }EOT

=head2 $Config::Ini::Expanded::interpolates

This boolean value (default: C<true>) will determine if expansion
templates in double quoted values will automatically be interpolated as
the Ini file is read in.  This includes expansion templates like
C<'{INI:section:name}'>, C<'{VAR:varname}'>, and
C<'{FILE:file_path}'>.  The C<'{INCLUDE:file_path}'> template will
always be expanded, regardless of the value of
C<$Config::Ini::Expanded::interpolates>, because it is at the section
level, not the value level.

Note that I<interpolation> is not the same as I<expansion>, such as
when C<get_expanded()> is called.  Interpolation performs a simple
one-pass replacement, while expansion performs a loop until there are
no more replacements to do.  It's like the difference between ...

 s/{(.*)}/replace($1)/ge;  # interpolation-like

and ...

 1 while s/{(.*)}/replace($1)/ge;  # expansion-like

See more about expansion templates below.

=head2 $Config::Ini::Expanded::expands

This boolean value (default: C<false>) will determine if expansion
templates in double quoted values will automatically be expanded as the
Ini file is read in.  This includes expansion templates like
C<'{INI:section:name}'>, C<'{VAR:varname}'>, and C<'{FILE:file_path}'>.

Note that this is different from what C<interpolates> does, because
templates will be fully expanded in a loop until there are no more
templates in the value.

See more about expansion templates below.

=head2 $Config::Ini::Expanded::inherits

The value of this setting will be a null string (the default) to
signify no inheritance, or an array reference pointing to an array of
Config::Ini::Expanded (or Config::Ini::Edit or Config::Ini) objects.

If such an array of objects is given, then inheritance can take place
when you call C<< $ini->get(...) >>, C<< $ini->get_var(...) >>, or
C<< $ini->get_loop(...) >>.

That is, if your object (C<$ini>) does not have a value for the
requested parameters, Config::Ini::Expanded will travel through the
array of other objects (in the order given) until a value is found.

=head2 $Config::Ini::Expanded::no_inherit

The value of this setting will be a null string (the default) to
signify that anything may be inherited, or a reference to a hash of
hashes specifying section/name combinations that should not be
inherited, e.g.,

 $Config::Ini::Expanded::no_inherit = { section => { name1 => 1, name2 => 1 } };

Note the true (C<1>) values for the names.

With the above example in force, when a program calls, e.g.,
C<$ini->get( section, 'name1' );> and gets no value from the C<$ini>
object, it will B<not> inherit from any object in the C<inherits>
list.

Note that the C<no_inherit> attribute does not affect inheritance that
may take place when a program calls C<$ini->get_var()> or
C<$ini->get_loop()>.

=head2 $Config::Ini::Expanded::no_override

The value of this setting will be a null string (the default) to
signify that any inherited values may be overridden, or a reference to
a hash of hashes specifying section/name combinations that may not be
overridden, e.g.,

 $Config::Ini::Expanded::no_override = { section => { name1 => 1, name2 => 1 } };

Note the true (C<1>) values for the names.

With the above example in force, if an Ini object's C<inherits>
attribute is true, the module will not allow C<section/name1> or
C<section/name2> to be set during the C<init()> of that object.  That
is, those section/name combinations may not be overridden in an ini
file (on the assumption that they will be set in an inherited object).

=head2 $Config::Ini::Expanded::loop_limit

During an expansion, e.g., when you call C<get_expanded()>, a loop is
started that ends when there are no more expansions to do.  If this
loops more than the value of C<'loop_limit'>, the program will croak
with a I<Loop alert>.

The default C<'loop_limit'> is 10, which should be sufficient for most
situations.  You can increase this limit if you need to have deeper
nesting levels in your expansions.

Looping expansions allow for nested expansion templates like:

 {FILE:{INI:section:{VAR:myname}}}

The inner-most templates are expanded first.

=head2 $Config::Ini::Expanded::size_limit

During an expansion like described above, the value being expanded may
grow longer.  If the length of the value exceeds the value of
C<'size_limit'>, the program will croak with a I<Loop alert> (on the
assumption that the large size is the result of a loop).

The default C<'size_limit'> is 1_000_000.  Increase this limit if you
need to allow for larger values.

=head2 $Config::Ini::Expanded::include_root

This value is the path were C<'{INCLUDE:file_path}'>,
C<'{JIT:file_path}'>, and C<'{FILE:file_path}'> templates will look
when file contents are read in.

 $Config::Ini::Expanded::include_root = '/web/data';
 my $ini = $Config::Ini::Expanded->new( string => <<'__' );
 [section]
 name = "{FILE:stuff}"
 {INCLUDE:ini/more.ini}
 __

In the above example, the value of C<< $ini->get(section=>'name') >>
would be the contents of C<'/web/data/stuff'>, and the contents of
C<'/web/data/ini/more.ini'> would be pulled in and used to augment the
Ini file contents.

=head2 $Config::Ini::Expanded::encoding

This value is the character encoding expected for the ini data.
It applies in new()/init() (which includes C<'{INCLUDE:file_path}'>)
and C<'{FILE:file_path}'>.

(The default value is false, which will not specify an encoding,
relying on perl's default behavior.)

 $Config::Ini::Expanded::encoding = 'utf8';
 my $ini = $Config::Ini::Expanded->new( string => <<'__' );
 [section]
 name = "{FILE:stuff}"
 {INCLUDE:ini/more.ini}
 __

In the above example, the character encoding for the C<'string'>
parameter value is assumed to be C<'utf8'>.  This encoding is
then assumed for the C<'{FILE:stuff}'> operation and for
C<'{INCLUDE:ini/more.ini}'>.

Set this to a false value, e.g., C<''> or C<0> to keep the
module from specifying any encoding, i.e., to assume the default
behavior.

=head2 $Config::Ini::Expanded::filter

This value is a subroutine reference.  This subroutine will
filter the data prior to expanding or interpolating it.  This
is intended to allow you to use different syntax for template
placeholders.  The subroutine expects to get a scalar reference
and will update that scalar.  For example, if you don't like
how this looks:

 {VAR:title}
 
 {LOOP:text}{LVAR:line}
 {END_LOOP:text}

then you might define a filter like this:

 $ini->filter( sub {
     for( ${$_[0]} ) {
         s| <TMPL_VAR   \s+ NAME="(.*?)"> |{VAR:$1}|gx;
         s| <TMPL_LOOP  \s+ NAME="(.*?)"> |{LOOP:$1}|gx;
         s| <TMPL_LVAR  \s+ NAME="(.*?)"> |{LVAR:$1}|gx;
         s| </TMPL_LOOP \s+ NAME="(.*?)"> |{END_LOOP:$1}|gx;
     }
 } );

then you could change your template to look like this:

 <TMPL_VAR NAME="title">
 
 <TMPL_LOOP NAME="text"><TMPL_LVAR NAME="line">
 </TMPL_LOOP NAME="text">

If you're familiar with HTML::Template, you'll notice that
the new syntax looks similar to that module's.  But there
isn't a one-to-one correspondence, e.g., VAR and LVAR are
two different things, and the </TMPL_LOOP...> end tag must
still include the loop name from the begin tag.

=head2 $Config::Ini::Expanded::callbacks

This value is a hashref of subroutine references.
These subroutines will be called if their keys
appear in one of the following template placeholders:

 {VAR:...}
 {INI:...}
 {LVAR:...}

Theses keys must appear in the "name" portion of
the placeholder as if they were subroutine calls
for that name, e.g.,

 {VAR:escape_url(query)}         (vs. {VAR:query})
 {INI:section:escape_html(text)} (vs. {INI:section:text})
 {LVAR:escape_js(parms)}         (vs. {LVAR:parms})

The respective callback keys would then be

 escape_url
 escape_html
 escape_js

e.g.,

 $ini->callbacks( {
     escape_url  => sub { ... },
     escape_html => sub { ... },
     escape_js   => sub { ... },
 } );

The intention for callbacks is to implement the usual
escape operations as implied by the above examples.
But callbacks may be named anything you want, and they
may do anything you want.  The subroutines will be passed
the value for the indicated name and should return the
escaped (or otherwised munged) value.

=head1 EXPANSION TEMPLATES

=head2 Templates Overview

The Config::Ini::Expanded module exists in order to implement expansion
templates.  They take the following forms:

 {INCLUDE:ini_file_path}
 
 {FILE:file_path}

 {INI:section:name}
 {IF_INI:section:name}.......{ELSE[[_IF_INI]:section:name]}...{END_IF_INI:section:name}
 {UNLESS_INI:section:name}...{ELSE[[_UNLESS_INI]:section:name]}...{END_UNLESS_INI:section:name}
 
 {INI:section:name:i}
 {IF_INI:section:name:i}.......{ELSE[[_IF_INI]:section:name:i]}...{END_IF_INI:section:name:i}
 {UNLESS_INI:section:name:i}...{ELSE[[_UNLESS_INI]:section:name:i]}...{END_UNLESS_INI:section:name:i}
 
 {VAR:varname}
 {IF_VAR:varname}.......{ELSE[[_IF_VAR]:varname]}...{END_IF_VAR:varname}
 {UNLESS_VAR:varname}...{ELSE[[_UNLESS_VAR]:varname]}...{END_UNLESS_VAR:varname}
 
 {LOOP:loopname}
 
     {LVAR:lvarname}
     {IF_LVAR:lvarname}.......{ELSE[[_IF_LVAR]:lvarname]}...{END_IF_LVAR:lvarname}
     {UNLESS_LVAR:lvarname}...{ELSE[[_UNLESS_LVAR]:lvarname]}...{END_UNLESS_LVAR:lvarname}
 
     {LOOP:[loopname:]nestedloop}
         {LVAR:[nestedloop:]nestedlvar}
     {END_LOOP:[loopname:]nestedloop}
 
     {LC:[loopname:]index}   (0 ... last index)
     {LC:[loopname:]counter} (1 ... last index + 1)
 
     {LC:[loopname:]first}
     {IF_LC:[loopname:]first}.......{ELSE[[_IF_LC][:loopname]:first]}...{END_IF_LC:[loopname:]first}
     {UNLESS_LC:[loopname:]first}...{ELSE[[_UNLESS_LC][:loopname]:first]}...{END_UNLESS_LC:[loopname:]first}
 
     {LC:[loopname:]last}
     {IF_LC:[loopname:]last}.......{ELSE[[_IF_LC]:...]}...{END_IF_LC:[loopname:]last}
     {UNLESS_LC:[loopname:]last}...{ELSE[[_UNLESS_LC]:...]}...{END_UNLESS_LC:[loopname:]last}
 
     {LC:[loopname:]inner}
     {IF_LC:[loopname:]inner}.......{ELSE[[_IF_LC]:...]}...{END_IF_LC:[loopname:]inner}
     {UNLESS_LC:[loopname:]inner}...{ELSE[[_UNLESS_LC]:...]}...{END_UNLESS_LC:[loopname:]inner}
 
     {LC:[loopname:]odd}
     {IF_LC:[loopname:]odd}.......{ELSE[[_IF_LC]:...]}...{END_IF_LC:[loopname:]odd}
     {UNLESS_LC:[loopname:]odd}...{ELSE[[_UNLESS_LC]:...]}...{END_UNLESS_LC:[loopname:]odd}
 
     {LC:[loopname:]break(nn)} (e.g., break(2) == "even")
     {IF_LC:[loopname:]break(nn)}.......{ELSE[[_IF_LC]:...]}...{END_IF_LC:[loopname:]break(nn)}
     {UNLESS_LC:[loopname:]break(nn)}...{ELSE}[[_UNLESS_LC]:...]...{END_UNLESS_LC:[loopname:]break(nn)}
 
 {END_LOOP:loopname}
 {IF_LOOP:loopname}.......{ELSE[[_IF_LOOP]:loopname]}...{END_IF_LOOP:loopname}
 {UNLESS_LOOP:loopname}...{ELSE[[_UNLESS_LOOP]:loopname]}...{END_UNLESS_LOOP:loopname}
 
Note that the C<'{END...}'> tags contain the full contents of the
corresponding beginning tag.  By putting this onus on the user (i.e.,
supplying the full beginning tag in multiple places), it removes from
the code the onus -- and processing time -- of parsing the text for
balanced tags.

It can also be viewed as a positive explicit statement of were a tag
begins and ends (albeit at the cost of verbosity).

A note about C<'{ELSE}'>: it is not strictly necessary to qualify
any C<'{ELSE}'> tag, i.e., by adding the full contents of the begin tag,
e.g., C<'{ELSE_IF_VAR:maple}'>.  This qualification is done internally
for any "bare" ELSE's.  But you may want to qualify your ELSE's anyway
for clarity, e.g.,

 {IF_VAR:tree}
     {IF_VAR:maple}{VAR:maple}
     {ELSE_IF_VAR:maple}{VAR:tree}
     {END_IF_VAR:maple}
 {ELSE_IF_VAR:tree}No tree.
 {END_IF_VAR:tree}

In addition, you can I<partially> qualify an ELSE with just a name, e.g.,

 {IF_VAR:tree}
     {IF_VAR:maple}{VAR:maple}
     {ELSE:maple}{VAR:tree}
     {END_IF_VAR:maple}
 {ELSE:tree}No tree.
 {END_IF_VAR:tree}

So if C<'{ELSE_IF_VAR:maple'> looks confusingly like "elsif" logic
is expected (it's not), then saying C<'{ELSE:maple}'> is an option.

A note about C<'{LOOP...}'>, C<'{LVAR...}'>, C<'{IF_LOOP...}'>,
C<'{UNLESS_LOOP...}'>, C<'{IF_LVAR...}'>, C<'{UNLESS_LVAR...}'>, and
their ELSE and END tags: The extra qualification, e.g.,
C<'{LOOP:loopname:nestedloop}'> vs. C<'{LOOP:nestedloop}'> is only
necessary if there is ambiguity and you need to disambiguate.  Without
any qualification, the named element (e.g., "nestedloop") will be
searched for first in the current loop and if not found, back through
the previous levels of loops.

Finally, a note about the loop context tags, C<'{LC...}'>,
C<'{IF_LC...}'>, C<'{UNLESS_LC...}'>, and their ELSE and END tags:  The
loopname portion of the tag is optional if the loop context is for the
current loop (vs. a parent loop).

Since this is usually the case, you'll usually leave off the loopname.
But if you want to access the loop context of a parent loop, the
loopname must be included.

=head2 Templates Specifics

=head3 {INCLUDE:ini_file_path}

The C<'{INCLUDE:ini_file_path}'> template is expanded during C<init()>
as the Ini file is read in.  This allows you to include Ini files in
other Ini files.  There is no limit to the amount of nesting allowed
other than perl's own deep recursion limits.

 [section]
 name = value
 
 {INCLUDE:second.ini}
 
 [another_section]
 name = value

The included Ini file will be loaded into the object as if its contents
existed in the main Ini file where the template appears.  It croaks if
the file cannot be opened.  It also croaks if C<< $self->include_root() >>
is not set (or is set to C<'/'>), or if C<'ini_file_path'> contains
two dots C<'..'>.

Note that this template is never expanded inside double-quoted values
or during calls to C<get_expanded()> or C<get_interpolated()>.  It is a
section-level template, not a value-level template.  See
C<'{FILE:file_path}'> below for value-level file inclusions.

=head3 {JIT:ini_file_path}

The C<'{JIT:ini_file_path}'> (Just-In-Time include) template is
similar to the C<'{INCLUDE:...}'> template in that it is a
section-level template, not a value-level one.  It is different in
that it isn't expanded during C<init()>.

Instead, as the Ini file is read in, the JIT template information is
saved, and it is associated with the section where the template
appears.

Later, if a value is requested from that section, and that value is
not defined -- and if there is a JIT template for that section --
I<then> the Ini named in the template is read in and merged with the
current instance.  If after this merging, the requested value is
defined, it is returned.

    [section]
    name = value
    
    {JIT:second.ini}
    
    [another_section]
    name = value

Like C<'{INCLUDE:...}'>, the included Ini file will be loaded into
the object as if its contents existed in the main Ini file where the
template appears.  It croaks if the file cannot be opened.  It also
croaks if C<< $self->include_root() >> is not set (or is set to
C<'/'>), or if C<'ini_file_path'> contains two dots C<'..'>.

This Just-In-Time concept lets you postpone loading Ini settings
that may never be used.  The JIT includes only happen when a value
in a section is requested that isn't defined.  But note that even
though the inclusion is triggered by a request for a particular
section, the included Ini file may
I<contain settings for any number of sections>.
And in fact, the value requested might not ever be defined.

This means that one could set up special sections designed just to
trigger these includes, e.g.,

    [jit1]
    {JIT:include1.ini}
    [jit2]
    {JIT:include2.ini}

The program could then call C<< get( jit1 => 'dummy' ) >> to read in
the C<include1.ini> file (which might not define 'dummy' anywhere),
and similarly, call C<< get( jit2 => 'dummy' ) >> to read in
C<include2.ini>.  These included files may then define anything you
want, including more JIT includes.

Finally, a section may define multiple JIT includes.  When a value
is requested that isn't defined, each JIT include file is included
until the requested value is found.  Any JIT includes that didn't get
included in that round may still be included later.

As with C<'{INCLUDE:...}'> a particular file will only be included
once, regardless of how many times it is given in an INCLUDE or JIT
template.

=head3 {FILE:file_path}

The C<'{FILE:file_path}'> template is expanded inside double-quoted
values and when you call C<get_expanded()> and C<get_interpolated()>.
It replaces the template with the contents of
C<'include_root/file_path'>.  It croaks if the file cannot be opened.
It also croaks if C<< $self->include_root() >> is not set (or is set to
C<'/'>), or if C<'file_path'> contains two dots C<'..'>.

 [website]
 homepage = {FILE:homepage.html}
 ...
 
 print $ini->get_expanded( website => 'homepage' );

=head3 {INI:section:name}

Includes:

 {INI:section:name}
 {INI:section:name:i}

The C<'{INI:section:name}'> template is expanded inside double-quoted
values and when you call C<get_expanded()> and C<get_interpolated()>.
It performs a call to C<get('section','name')> and replaces the
template with the return value.  If the value is undefined, the
template is replaced silently with a null string.

You can provide an occurrence value (array subscript), e.g.,

 name = <<""
 This is the first value: {INI:section:name:0}, and
 this is the second: {INI:section:name:1}.
 <<

=head3 {IF/UNLESS_INI:section:name}

Includes:

 {IF_INI:section:name}...[{ELSE[[_IF_INI]:section:name]}...]{END_IF_INI:section:name}
 {IF_INI:section:name:i}...[{ELSE[[_IF_INI]:section:name:i]}...]{END_IF_INI:section:name:i}
 {UNLESS_INI:section:name}...[{ELSE[[_UNLESS_INI]:section:name]}...]{END_UNLESS_INI:section:name}
 {UNLESS_INI:section:name:i}...[{ELSE[[_UNLESS_INI]:section:name:i]}...]{END_UNLESS_INI:section:name:i}

These templates provide for conditional text blocks based on the truth
(or existence) of a named value in a section.  An optional C<'{ELSE}'>
divider supplies an alternative text block.

Note that the C<'{END...}'> tags must contain the full contents of the
beginning tag, including the section, name, and (if supplied) index.

=head3 {VAR:varname}

The C<'{VAR:varname}'> template is expanded inside double-quoted values
and when you call C<get_expanded()> and C<get_interpolated()>.  It
performs a call to C<get_var('varname')> and replaces the template with
the return value.  If the value is undefined, the template is replaced
silently with a null string.

 [letter]
 greeting = Hello {VAR:username}, today is {VAR:today}.
 ...
 
 $greeting = $ini->get_expanded( letter => 'greeting' );

=head3 {IF/UNLESS_VAR:varname}

Includes:

 {IF_VAR:varname}...[{ELSE[[_IF_VAR]:varname]}...]{END_IF_VAR:varname}
 {UNLESS_VAR:varname}...[{ELSE[[_UNLESS_VAR]:varname]}...]{END_UNLESS_VAR:varname}

These templates provide for conditional text blocks based on the truth
(or existence) of a variable.  An optional C<'{ELSE}'> divider supplies
an alternative text block.

Note that the C<'{END...}'> tags must contain the full contents of the
beginning tag, including the variable name.

=head3 {LOOP:loopname}

Includes:

 {LOOP:loopname}...{LVAR:lvarname}...{END_LOOP:loopname}

This template enables loops that are similar to those in
HTML::Template, i.e., they iterate over an array of hashes.  The
C<'{LVAR:...}'> tag is where you display the values from each hash.

Use set_loop() to provide the array reference -- and it may include
nested loops, e.g.,

 $ini->set_loop( loop1 => [{
     var1 => 'val1',
     var2 => 'val2',
     loop2 => [{ innervar1 => 'innerval1', innervar2 => 'innerval1' }]
     }] );
 
 {LOOP:loop1}
     {LVAR:var1}{LVAR:var2}
     {LOOP:loop2}{LVAR:innervar1}{LVAR:innervar2}{END_LOOP:loop2}
 {END_LOOP:loop1}

Note that nearly everything is "global".  In other words,
C<'{VAR:...}'> and C<'{INI:...}'> tags may be displayed inside any
loop.  Also, C<'{LOOP:...}'> tags at the top level (named in the
set_loop() call) may be displayed inside any other loop.  And, nested
C<'{LOOP:...}'> tags may contain C<'{LOOP:...}'> and C<'{LVAR:...}'>
tags from parent loops.  In this case, loop name and lvar name
collisions favor the current loop and then the closest parent.

So given:

 $ini->put( section1 => 'name1', 'value1' );
 $ini->set_var( var1 => 'val1' );
 $ini->set_loop( loop1 => [{
         var1 => 'loop1val1',
         var2 => 'loop1val2',
         loop2 => [{
             loop2var1 => 'loop2val1',
             var2      => 'loop2val2'
             }]
     }],
     loop3 => [{
         var1      => 'loop3val1',
         loop3var2 => 'loop3val2'
         }]
     );

The following is possible:

 {LOOP:loop1}
     {INI:section1:name1}{VAR:var1}
     {LVAR:var1}              (i.e., 'loop1val1')
     {LVAR:var2}              (i.e., 'loop1val2')
     {LOOP:loop2}
         {INI:section_a:name1}{VAR:var1} (same as above)
         {LVAR:var1}          (i.e., 'loop1val1')
         {LVAR:loop2var1}     (i.e., 'loop2val1')
         {LVAR:var2}          (i.e., 'loop2val2')
         {LOOP:loop3}
             {LVAR:var1}      (i.e., 'loop3val1')
             {LVAR:loop3var2} (i.e., 'loop3val2')
             {LVAR:var2}      (i.e., 'loop2val2')
         {END_LOOP:loop3}
     {END_LOOP:loop2}
 {END_LOOP:loop1}

Note that when a top-level loop is displayed inside a another loop, the
other loop is considered a "parent" for the purposes of resolving the
lvar names, e.g., C<'{LVAR:var2}'> inside loop3 above resolves to the
value from loop2.  If loop3 were not inside another loop that defined
var2, then C<'{LVAR:var2}'> would be null inside loop3.

What can't be displayed are nested loops and lvars from a different
loop.  For example, the following is not possible:

 {LOOP:loop3}
     {LOOP:loop2}
     ...
     {END_LOOP:loop2}
 {END_LOOP:loop3}

This is because there would normally be many "loop2"s and, outside the
context of C<'{LOOP:loop1}'>, a reference to loop2 would be ambiguous
(not to mention being tough to locate).

On the other hand, the following I<is> possible:

 {LOOP:loop1}
     {LOOP:loop3}
         {LOOP:loop2}
             {LVAR:var1}  (i.e., 'loop3val1')
             {LVAR:var2}  (i.e., 'loop2val2')
         {END_LOOP:loop2}
     {END_LOOP:loop3}
 {END_LOOP:loop1}

This is because loop2 is now referenced in the context of looping
through loop1, so determining what to display is not ambiguous.  The
fact that loop2 is being displayed inside loop3 (inside loop1) doesn't
alter the fact that loop1 is now one of loop2's parents.  What it does
alter is where the value for var1 comes from, i.e., from loop3 (the
closest parent), not loop1.

This illustrates again that for the purposes of loop and lvar name
resolutions, a parent relationship, that is based on how the loops are
displayed, trumps a parent relationship that is based on how the loops
are defined.

If you're lost at this point, don't worry too much.  Most of the time,
things will happen as you intend.  The above explanation attempts to be
as complete as possible both to explain why things might not happen as
you intended and to show what is possible (that, e.g., isn't possible
in HTML::Template).

=head4 Array Loops

Normally, a loop iterates over an array of hashes, which you define
using set_loop(), e.g.,

 $ini->set_loop( loop1 => [
      {
         var1 => 'one fish',
         var2 => 'two fish',
      },
      {
         var1 => 'red fish',
         var2 => 'blue fish',
      },
 ]);

It is also possible to iterate over an array of scalar values, e.g.,

 $ini->set_loop( fish => [
     'one fish',
     'two fish',
     'red fish',
     'blue fish',
 ]);

The above loop is treated as if you had set it as follows (note that
there is only one key in each hash, and it's the same as the "parent"
key):

 $ini->set_loop( fish => [
     { fish => 'one fish'  },
     { fish => 'two fish'  },
     { fish => 'red fish'  },
     { fish => 'blue fish' },
 ]);

The template syntax for both types of loops is exactly the same, e.g.,

 {LOOP:fish}{LVAR:fish}{END_LOOP:fish}

=head3 {IF/UNLESS_LOOP:loopname}

Includes:

 {IF_LOOP:loopname}...[{ELSE[[_IF_LOOP]:loopname]}...]{END_IF_LOOP:loopname}
 {UNLESS_LOOP:loopname}...[{ELSE[[_UNLESS_LOOP]:loopname]}...]{END_UNLESS_LOOP:loopname}

These templates provide for conditional text blocks based on the
existence of a loop.  An optional C<'{ELSE}'> divider supplies an
alternative text block.

Note that the C<'{END...}'> tags must contain the full contents of the
beginning tag, including the loop name.

=head3 {LVAR:lvarname}

As stated above, this template is used inside a C<'{LOOP...}'> to
display the values from each hash in the loop.  Outside a loop, this
template will be silently replaced with nothing.

Inside multiple nested loops, this template will be replaced with the
value defined in the current loop or with a value found in one of the
parent loops -- from the closest parent if it's defined in more than
one.  Note that for name collisions, "closest parent" is relative to
how the templates are being displayed rather than how they are defined
in set_loop().

Note that unlike in HTML::Template (and it's family of modules),
C<'{LVAR...}'> is distinct from C<'{VAR...}'>.  So you may define VAR's
with the same names as LVAR's (values inside loops) without problems,
because there are separate tags to access the separate "name spaces",
as it were.

Note also that there is no set_lvar() method.  This is because LVAR's
are always set inside loops via set_loop().

=head3 {IF_LVAR:lvarname}

Includes:

 {IF_LVAR:lvarname}...[{ELSE[[_IF_LVAR]:lvarname]}...]{END_IF_LVAR:lvarname}
 {UNLESS_LVAR:lvarname}...[{ELSE[[_UNLESS_LVAR]:lvarname]}...]{END_UNLESS_LVAR:lvarname}

These templates provide for conditional text blocks based on the truth
(or existence) of a value inside a loop.  An optional C<'{ELSE}'>
divider supplies an alternative text block.

Note that the C<'{END...}'> tags must contain the full contents of the
beginning tag, including the lvar name.

As with C<'{LVAR...}'>, these conditionals do not have reasonable
meaning outside a loop.  That is, if used outside a loop, these will
always register as false, so I<something> might be displayed, but it
probably won't mean what you think.

=head2 Loop Context Variables

In HTML::Template (and other modules based on it, like
HTML::Template::Compiled) there are values you can access that reflect
the current loop context, i.e., C<__first__>, C<__last__>, C<__inner__>,
C<__odd__>, C<__counter__>, as well as C<__index__>, and C<__break__> (from
H::T::C).

These values are supported in this module, though without the double
underscores (since the syntax separates them from the loop name).  In
addition, in this module, these values are available not only for the
current loop, but also for parent loops (because the syntax includes
the loop name).

As mentioned above, the loopname portion of the tag is optional if the
loop context is for the current loop (vs. a parent loop).

Since this is usually the case, you'll usually leave off the loopname.
But if you want to access the loop context of a parent loop, the
loopname must be included.

=head3 {LC:loopname:index} (0 ... last index)

The current index of the loop (starting with 0).  This differs from
C<'{LC:loopname:counter}'>, which starts with 1.

=head3 {LC[:loopname]:counter} (1 ... last index + 1)

The current counter (line number?) of the loop (starting with 1).  This
differs from C<'{LC:loopname:index}'>, which starts with 0.

=head3 {LC/IF_LC/UNLESS_LC:loopname:first}

Includes:

 {LC[:loopname]:first}
 {IF_LC[:loopname]:first}.......{ELSE[[_IF_LC][:loopname]:first]}...{END_IF_LC[:loopname]:first}
 {UNLESS_LC[:loopname]:first}...{ELSE[[_UNLESS_LC][:loopname]:first]}...{END_UNLESS_LC[:loopname]:first}

The template C<'{LC:loopname:first}'> displays "1" (true) if the
current iteration is the first one, "" (false) if not.  The IF and
UNLESS templates provide for conditional text blocks based on these
boolean values.

=head3 {LC/IF_LC/UNLESS_LC:loopname:last}

Includes:

 {LC[:loopname]:last}
 {IF_LC[:loopname]:last}.......{ELSE[[_IF_LC][:loopname]:last]}...{END_IF_LC[:loopname]:last}
 {UNLESS_LC[:loopname]:last}...{ELSE[[_UNLESS_LC][:loopname]:last]}...{END_UNLESS_LC[:loopname]:last}

The template C<'{LC:loopname:last}'> displays "1" (true) if the current
iteration is the last one, "" (false) if not.  The IF and UNLESS
templates provide for conditional text blocks based on these boolean
values.

=head3 {LC/IF_LC/UNLESS_LC:loopname:inner}

Includes:

 {LC[:loopname]:inner}
 {IF_LC[:loopname]:inner}.......{ELSE[[_IF_LC][:loopname]:inner]}...{END_IF_LC[:loopname]:inner}
 {UNLESS_LC[:loopname]:inner}...{ELSE[[_UNLESS_LC][:loopname]:inner]}...{END_UNLESS_LC[:loopname]:inner}

The template C<'{LC:loopname:inner}'> displays "1" (true) if the
current iteration is not the first one and is not the last one, ""
(false) otherwise.  The IF and UNLESS templates provide for conditional
text blocks based on these boolean values.

=head3 {LC/IF_LC/UNLESS_LC:loopname:odd}

Includes:

 {LC[:loopname]:odd}
 {IF_LC[:loopname]:odd}.......{ELSE[[_IF_LC][:loopname]:odd]}...{END_IF_LC[:loopname]:odd}
 {UNLESS_LC[:loopname]:odd}...{ELSE[[_UNLESS_LC][:loopname]:odd]}...{END_UNLESS_LC[:loopname]:odd}

The template C<'{LC:loopname:odd}'> displays "1" (true) if the current
iteration is odd, "" (false) if not.  The IF and UNLESS templates
provide for conditional text blocks based on these boolean values.

=head3 {LC/IF_LC/UNLESS_LC:loopname:break(nn)} (e.g., break(2) == "even")

Includes:

 {LC[:loopname]:break(nn)} (e.g., break(2) == "even")
 {IF_LC[:loopname]:break(nn)}.......{ELSE[[_IF_LC][:loopname]:break(nn)]}...{END_IF_LC[:loopname]:break(nn)}
 {UNLESS_LC[:loopname]:break(nn)}...{ELSE[[_UNLESS_LC][:loopname]:break(nn)]}...{END_UNLESS_LC[:loopname]:break(nn)}

The template C<'{LC:loopname:break(nn)}'> displays "1" (true) if the
current iteration modulo the number 'nn' is true, "" (false) if not.
The IF and UNLESS templates provide for conditional text blocks based on
these boolean values.

Note that C<'{LC:loopname:break(2)}'> would be like saying
C<'{LC:loopname:even}'> if the "even" template existed -- which
it doesn't.

This feature is designed to allow you to insert things, e.g., column
headings, at regular intervals in a loop.

=head2 Postponed Expansion/Interpolation

Expansion and interpolation can be I<postponed> for value-level
expansion templates by placing an exclamation point (or 'bang' or 'not'
symbol) just before the opening brace of an expansion template, e.g.,

 !{INI:section:name}
 !{IF_INI:section:name}...{END_IF_INI:section:name} (and UNLESS)
 !{VAR:varname}
 !{IF_VAR:varname}...{END_IF_VAR:varname} (and UNLESS)
 !{LOOP:loopname}...!{LVAR:lvarname}...!{LC:counter}...{END_LOOP:loopname}
 !{IF_LOOP:loopname}...{END_IF_LOOP:loopname} (and UNLESS)
 !{FILE:file_path}

This feature allows you to use expansion templates to create other
expansion templates that will be expanded later (by your own program or
another program).

Note that postponing loops adds an additional complication:  To
postpone a nested loop, you must also postpone all of the loop-related
templates within the loop (sorry about that).

You can do this even if the loop isn't nested (as shown above), if you
want to be safe.

Depending on your needs, you may postpone multiple times with multiple
bangs, e.g.,

 !!{INI:section:name}

Each exclamation point will postpone the expansion one more time.

Note that these postponements happen inside C<expand()> and
C<interpolate()>.  Since the C<'{INCLUDE:ini_file_path}'> template is
expanded in C<init()>, it is not a value-level template and does not
have the postponement feature; its expansion cannot be postponed.

=head1 METHODS

=head2 Initialization Methods

=head3 new()

Calling options:

 new( 'filename' )
 new( file => 'filename' )
 new( fh => $filehandle )
 new( string => $string )
 new( string => $string, file => 'filename' )
 new( fh => $filehandle, file => 'filename' )
 new( file => 'filename', keep_comments => 0 )
 new( file => 'filename', heredoc_style => '{}' ), etc.

Use C<new()> to create an object, e.g.,

 my $ini = Config::Ini::Expanded->new( 'inifile' );

If you pass any parameters, the C<init()> method will be called.  If
you pass only one parameter, it's assumed to be the file name.
Otherwise, use the named parameters, C<'file'>, C<'fh'>, or C<'string'>
to pass a filename, filehandle (already open), or string.  The string
is assumed to look like the contents of an Ini file.

The parameter, C<'fh'> takes precedent over C<'string'> which takes
precedent over C<'file'>.  You may pass C<< file => 'filename' >> with
the other parameters to set the C<'file'> attribute.

Other parameters are:

C<'keep_comments'> to override the default: false.

C<'heredoc_style'> to override the default: C<< '<<' >>.
The values accepted for heredoc_style are C<< '<<' >>, C<< '<<<<' >>,
C<'{'>, or C<'{}'>.

C<'interpolates'> to override the default: 1.

C<'expands'> to override the default: 0.

C<'inherits'> to override the default: C<''> (no inheritance).

C<'loop_limit> to override the default: 10.

C<'size_limit'> to override the default: 1_000_000.

C<'include_root'> to override the default: C<''> (inclusions not
allowed).

C<'encoding'> to override the default: 'utf8'.

Also see GLOBAL SETTINGS above.

If you do not pass any parameters to C<new()>, you can later call
C<init()> with the same parameters described above.

By default, if you give a filename or string, the module will not
specify any encoding, and thus will rely on perl's default behavior.
You can change this by setting $Config::Ini::encoding, e.g.,

 $Config::Ini::encoding = "utf8";
 my $ini = Config::Ini->new( file => 'filename' );

Alternatively, you may open the file yourself using the desired
encoding and send the filehandle to new() (or init());

=head3 init()

Calling options:

 init( 'filename' )
 init( file => 'filename' )
 init( fh => $filehandle )
 init( string => $string )
 init( string => $string, file => 'filename' )
 init( fh => $filehandle, file => 'filename' )
 init( file => 'filename', keep_comments => 0 )
 init( file => 'filename', heredoc_style => '{}' ), etc.

Example:

 my $ini = Config::Ini::Expanded->new();
 $ini->init( 'filename' );

=head2 Get Methods

=head3 get_sections()

Use C<get_sections()> to retrieve a list of the sections in the Ini
file.  They are returned in the order they appear in the file.

 my @sections = $ini->get_sections();

If there is a 'null section', it will be the first in the list.

If a section appears twice in a file, it only appears once in this
list.  This implies that ...

 [section1]
 name1 = value
 
 [section2]
 name2 = value
 
 [section1]
 name3 = value

is the same as ...

 [section1]
 name1 = value
 name3 = value
 
 [section2]
 name2 = value

The C<as_string()> method will output the latter.

=head3 get_names()

Calling options:

 get_names( $section )
 get_names( '' )
 get_names()

Use C<get_names()> to retrieve a list of the names in a given section.

 my @names = $ini->get_names( $section );

They are returned in the order they appear in the section.

If a name appears twice in a section, it only appears once in this
list.  This implies that ...

 [section]
 name1 = value1
 name2 = value2
 name1 = another

is the same as ...

 [section]
 name1 = value1
 name1 = another
 name2 = value2

The C<as_string()> method will output the latter.

Calling C<get_names()> without a parameter is the same as calling it
with a null string: it retrieves the names from the 'null section'.
The two lines below are equivalent.

 @names = $ini->get_names();
 @names = $ini->get_names( '' );

=head3 get()

Calling options:

 get( $section, $name )
 get( $section, $name, $i )
 get( $name )  (assumes $section eq '')
 get( '', $name, $i )

Use C<get()> to retrieve the value or values for a given name.

Note: when an Ini object is initialized, if a name appears more than
once in a section, the values are pushed onto an array, and C<get()>
will return this array of values.

 my @values = $ini->get( $section, $name );

Pass an array subscript as the third parameter to return only one of
the values in this array.

 my $value = $ini->get( $section, $name, 0 );  # get first one
 my $value = $ini->get( $section, $name, 1 );  # get second one
 my $value = $ini->get( $section, $name, -1 ); # get last one

If the Ini file lists names at the beginning, before any sections are
given, the section name is assumed to be a null string (C<''>).  If you
call C<get()> with just one parameter, it is assumed to be a name in
this 'null section'.  If you want to pass an array subscript, then you
must also pass a null string as the first parameter.

 my @values = $ini->get( $name );         # assumes $section eq ''
 my $value  = $ini->get( '', $name, 0 );  # get first occurrence
 my $value  = $ini->get( '', $name, -1 ); # get last occurrence

If the section and name are not found, C<get()> will inherit from any
inherited objects, and if still not found, will return no value.

=head3 get_interpolated()

Calling options:

 get_interpolated( $section, $name )
 get_interpolated( $section, $name, $i )
 get_interpolated( $name )  (assumes $section eq '')
 get_interpolated( '', $name, $i )

Use C<get_interpolated()> to retrieve the value or values for a given
name just as you would use C<get()> (see above).  But unlike with
C<get()>, the value will be interpolated and then returned.

 $value = $ini->get_interpolated( $section, $name );

The following expansion templates may be interpolated:

 {INI:section:name}
 {INI:section:name:i}

It expands these by calling C<get('section','name')> or
C<get('section','name',i)> and C<interpolate()>.

 {VAR:varname}

It expands this by calling C<get_var('varname')> and C<interpolate()>.
See C<get_var()> below.

 {FILE:file_path}

It expands this by reading in the contents of
C<'include_root/file_path'>.

If expansion templates are nested, e.g.,

 {FILE:{INI:section:{VAR:varname}}}

only the inner-most templates will be expanded, because
C<get_interpolated()> will only do one pass through the value.

If any template resolves to an undefined value, it will be replaced
with a null string.

=head3 interpolate( $value )

Use C<interpolate()> to interpolate a value that may contain expansion
templates. The interpolated value is returned.  Typically you would not
call C<interpolate()>, but would instead call C<get_interpolated()>,
which itself calls C<interpolate()>.  But it is a supported method for
those times when, for example, you might want to C<get()> an
uninterpolated value and expand it later.

 $value = $ini->get( $section, $name );
 ...
 $value = $ini->interpolate( $value );

=head3 get_expanded()

Calling options:

 get_expanded( $section, $name )
 get_expanded( $section, $name, $i )
 get_expanded( $name )  (assumes $section eq '')
 get_expanded( '', $name, $i )

Use C<get_expanded()> to retrieve the value or values for a given name
just as you would use C<get()> (see above).  But unlike with C<get()>,
the value will be expanded and then returned.

 $value = $ini->get_expanded( $section, $name );

The following expansion templates may be expanded:

 {INI:section:name}
 {INI:section:name:i}

It expands these by calling C<get('section','name')> or
C<get('section','name',i)> and C<expand()>.

 {VAR:varname}

It expands this by calling C<get_var('varname')> and C<expand()>.  See
C<get_var()> below.

 {FILE:file_path}

It expands this by reading in the contents of
C<'include_root/file_path'>.

Expansion templates may be nested, e.g.,

 {FILE:{INI:section:{VAR:varname}}}

The inner-most templates are expanded first.

If any template resolves to an undefined value, it will be replaced
with a null string.

If there is a I<Loop alert> condition (e.g., the number of expansion
loops exceeds C<'loop_limit'>, or the size of the value being expanded
exceeds C<'size_limit'>), C<get_expanded()> (actually C<expand()>) will
croak.

=head3 expand( $value )

Use C<expand()> to expand a value that may contain expansion templates.
The expanded value is returned.  Typically you would not call
C<expand()>, but would instead call C<get_expanded()>, which itself
calls C<expand()>.  But it is a supported method for those times when,
for example, you might want to C<get()> an unexpanded value and expand
it later.

 $value = $ini->get( $section, $name );
 ...
 $value = $ini->expand( $value );

If there is a I<Loop alert> condition (e.g., the number of expansion
loops exceeds C<'loop_limit'>, or the size of the value being expanded
exceeds C<'size_limit'>), C<expand()> will croak.

=head2 Add/Set/Put Methods

Here, I<add> denotes pushing values onto the end, I<set>, modifying a
single value, and I<put>, replacing all values at once.

=head3 add()

Calling options:

 add( $section, $name, @values )
 add( '', $name, @values )

Use C<add()> to add to the value or values of an option.  If the option
already has values, the new values will be added to the end (pushed
onto the array).

 $ini->add( $section, $name, @values );

To add to the 'null section', pass a null string.

 $ini->add( '', $name, @values );

=head3 set()

Calling options:

 set( $section, $name, $i, $value )
 set( '', $name, $i, $value )

Use C<set()> to assign a single value.  Pass C<undef> to remove a value
altogether.  The C<$i> parameter is the subscript of the values array to
assign to (or remove).

 $ini->set( $section, $name, -1, $value ); # set last value
 $ini->set( $section, $name, 0, undef );   # remove first value

To set a value in the 'null section', pass a null string.

 $ini->set( '', $name, 1, $value ); # set second value

=head3 put()

Calling options:

 put( $section, $name, @values )
 put( '', $name, @values )

Use C<put()> to assign all values at once.  Any existing values are
overwritten.

 $ini->put( $section, $name, @values );

To put values in the 'null section', pass a null string.

 $ini->put( '', $name, @values );

=head3 set_var( 'varname', $value )

Use C<set_var()> to assign a value to a C<'varname'>.  This value will
be substituted into any expansion templates of the form,
C<'{VAR:varname}'>.

 $ini->set_var( 'today', scalar localtime );

=head3 get_var( $varname )

Use C<get_var()> to retrieve the value of a varname.  This method is
called by C<get_expanded()>, C<get_interpolated()>, C<expand()>, and
C<interpolate()> to expand templates of the form, C<'{VAR:varname}'>.

 $today = $ini->get_var( 'today' );

If the C<$varname> is not found, C<get_var()> will inherit from any
inherited objects, and if still not found, will return no value.

=head3 set_loop( 'loopname', $loop_structure )

Use C<set_loop()> to assign a loop structure to a C<'loopname'>.  A
loop structure is an array of hashes.  The parameter,
C<'$loop_structure'>, should be this array's reference.

This value will be substituted into any expansion templates of the
form, C<'{LOOP:loopname}...{END_LOOP:loopname}'>.

 $ini->set_loop( 'months', [{1=>'jan'},{2=>'feb'},...,{12=>'dec'}] );

The following will remove a loop:

 $ini->set_loop( 'months' );
 $ini->set_loop( 'months' => undef );
 $ini->set_loop( { 'months' => undef } );

The following will remove all loops:

 $ini->set_loop( undef );

=head3 get_loop( $loopname )

Use C<get_loop()> to retrieve the loop structure for a loopname.  This
method is called by C<get_expanded()>, C<get_interpolated()>,
C<expand()>, and C<interpolate()> to expand templates of the form,
C<'{LOOP:loopname}...{END_LOOP:loopname}'> (as well as
C<'{IF_LOOP...}'> and C<'{UNLESS_LOOP...}'>).

 $aref = $ini->get_loop( 'months' );

If the C<$loopname> is not found, C<get_loop()> will inherit from any
inherited objects, and if still not found, will return no value.

=head2 Delete Methods

=head3 delete_section()

Calling options:

 delete_section( $section )
 delete_section( '' )
 delete_section()

Use C<delete_section()> to delete an entire section, including all of
its options and their values.

 $ini->delete_section( $section )

To delete the 'null section', don't pass any parameters or pass a null
string.

 $ini->delete_section();
 $ini->delete_section( '' );

=head3 delete_name()

Calling options:

 delete_name( $section, $name )
 delete_name( '', $name )
 delete_name( $name )

Use C<delete_name()> to delete a named option and all of its values
from a section.

 $ini->delete_name( $section, $name );

To delete an option from the 'null section', pass just the name, or
pass a null string.

 $ini->delete_name( $name );
 $ini->delete_name( '', $name );

To delete just some of the values, you can use C<set()> with a
subscript, passing C<undef> to delete each one.  Or you can first get them
into an array using C<get()>, modify them in that array (e.g., delete
some), and then use C<put()> to replace the old values with the
modified ones.

=head2 Other Accessor Methods

=head3 file()

Calling options:

 file()
 file( $filename )
 file( undef )

Use C<file()> to get or set the name of the object's Ini file.  Pass the
file name to set the value.  Pass C<undef> to remove the C<'file'> attribute
altogether.

 $inifile_name = $ini->file();  # get
 $ini->file( $inifile_name );   # set
 $ini->file( undef );           # remove

=head3 keep_comments( $boolean )

Use C<keep_comments()> to get or set the object's C<'keep_comments'>
attribute.  The default for this attribute is false, i.e., do not keep
comments.  Pass a true value to turn comments on.

 $boolean = $ini->keep_comments();  # get
 $ini->keep_comments( $boolean );   # set

C<keep_comments()> accesses the value of the flag that is stored in the
object -- not the value of the global setting.

=head3 heredoc_style( $style )

Use C<heredoc_style()> to get or set the default style used when
heredocs are rendered by C<as_string()>.

 $style = $ini->heredoc_style();  # get
 $ini->heredoc_style( $style );   # set

The value passed should be one of C<< '<<' >>, C<< '<<<<' >>, C<'{'>,
or C<'{}'>.  The default is C<< '<<' >>.

C<heredoc_style()> accesses the value of the style that is stored in
the object -- not the value of the global setting.

=head3 interpolates( 1 )

Use C<interpolates()> to get or set the C<'interpolates'> flag.  This
boolean value will determine if expansion templates in double quoted
values will automatically be interpolated as the Ini file is read in.
Also see C<$Config::Ini::Expanded::interpolates> for more details.

C<interpolates()> accesses the value of the flag that is stored in the
object -- not the value of the global setting.

=head3 expands( 0 )

Use C<expands()> to get or set the C<'expands'> flag.  This boolean
value will determine if expansion templates in double quoted values
will automatically be expanded as the Ini file is read in.  Also see
C<$Config::Ini::Expanded::expands> for more details.

C<expands()> accesses the value of the flag that is stored in the
object -- not the value of the global setting.

=head3 inherits( [$ini_obj1, $ini_obj2, ... ] )

Use C<inherits()> to get or set the C<'inherits'> attribute.  The value
should be a null string to disable inheritance, or an array reference,
like the anonymous array shown above.  This array should contain a list
of Ini objects (Config::Ini, Config::Ini::Edit, or
Config::Ini::Expanded).

It must be an array reference even if there is only one object to
inherit from, e.g.,

 $ini->inherits( [$ini_obj] );

Also see C<$Config::Ini::Expanded::inherits> for more details.

Note: B<don't> inherit from yourself.  If you do, you will get a deep
recursion error if you call C<get()> or C<get_var()> and trigger
inheritance.  Note also that inheriting from yourself can happen if you
inherit from an object that inherits from you.

C<inherits()> accesses the value of the attribute that is stored in the
object -- not the value of the global setting.

=head3 loop_limit( 10 )

Use C<loop_limit()> to get or set the C<'loop_limit'> value.  If an
expansion loops more than the value of C<'loop_limit'>, the program
will croak with a I<Loop alert>.  Also see
C<$Config::Ini::Expanded::loop_limit> above for more details.

C<loop_limit()> accesses the limit value that is stored in the
object -- not the value of the global setting.

=head3 size_limit( 1_000_000 )

Use C<size_limit()> to get or set the C<'size_limit'> value.  If the
length of an expanded value exceeds the value of C<'size_limit'>, the
program will croak with a I<Loop alert>.  Also see
C<$Config::Ini::Expanded::size_limit> above for more details.

C<size_limit()> accesses the limit value that is stored in the
object -- not the value of the global setting.

=head3 include_root( $path )

Use C<include_root()> to get or set the C<'include_root'> value.  This
value is the path were C<'{INCLUDE:file_path}'> and
C<'{FILE:file_path}'> will begin looking when file contents are read
in.  Also see C<$Config::Ini::Expanded::include_root> for more
details.

When a C<'{INCLUDE:file_path}'> or C<'{FILE:file_path}'> template is
expanded, it will croak if C<'include_root'> is not set (or is set to
"/"), or if C<'file_path'> contains two dots "..".

C<include_root()> accesses the value of the path
that is stored in the object -- not the value of the global
setting.

=head3 encoding( 'utf8' )

Use C<encoding()> to get or set the C<'encoding'> value.  This
value will determine the character encoding that is assumed when
the ini object is created and when other files are included.
Also see C<$Config::Ini::Expanded::encoding> for more details.

C<encoding()> accesses the value of the flag that is stored in the
object -- not the value of the global setting.

See also C<init()> and GLOBAL SETTINGS above.

=head3 vattr( $section, $name, $i, $attribute, $value, ... )

Use vattr() to get or set value-level attributes,
which include:

 heretag   : 'string'
 herestyle : ( {, {}, <<, or <<<< )
 quote     : ( ', ", s, d, single, or double )
 nquote    : ( ', ", s, d, single, or double )
 equals    : ( '=', ':', ' = ', ': ', etc. )
 escape    : ( :slash and/or :html )
 indented  : indentation value (white space)
 json      : boolean
 comment   : 'string'

If C<$i> is undefined, C<0> is assumed.  If there's an C<$attribute>,
but no C<$value>, the value of that attribute is returned.

 $value = $ini->vattr( $section, $name, 0, 'heretag' );  # get one

If no C<$attribute> is given, C<vattr()> returns all of the attribute
names and values as a list (in pairs).

 %attrs = $ini->vattr( $section, $name, 1 ); # get all

If C<$attribute> is a hashref, values are set from that hash.

 $ini->vattr( $section, $name, 1, { heretag=>'EOT', herestyle=>'{}' } );

Otherwise, attributes and values may be passed as named parameters.

 $ini->vattr( $section, $name, 1, heretag=>'EOT', herestyle=>'{}' );

These value attributes are used to replicate the ini file when
C<as_string()> is called.

The attributes C<'escape'>, C<'indented'>, and C<'json'> correspond to
the similarly named heredoc modifiers; see C<Heredoc Modifiers> above.
The values of C<'heretag'>, C<'herestyle'>, and C<'quote'> are used to
begin and end the heredoc.  Additionally, if double quotes are called
for, characters in the value will be escaped according to the
C<'escape'> value.

The value of C<'comment'> will be appended after the value, or if a
heredoc, after the beginning of the heredoc.  Note that the comment may
also be accessed using C<set_comment()> and C<get_comment()>.  See
Comments Accessor Methods below.

The value of C<'equals'> will be output between the name and value,
e.g., C<' = '> in C<'name = value'>.  The setting, C<'nquote'>, is to
the name what C<'quote'> is to the value, i.e., if C<"'">, the name
will be single quoted, if C<'"'>, double quoted.

Note that replicating the ":parse" heredoc modifier is not supported,
so if a file containing a ":parse" modifier is read and then rewritten
using C<as_string()>, the values will be written in their parsed form, and
may not be a heredoc any more. For example:

 [section]
 name = <<:parse
 one
 two
 <<

would be written by as_string() like this:

 [section]
 name = one
 name = two

=head2 Comments Accessor Methods

An Ini file may contain comments.  Normally, when your program reads an
Ini file, it doesn't care about comments.  In Config::Ini::Expanded,
keep_comments is false by default.

Set C<$Config::Ini::Expanded::keep_comments = 1;> if you go want the
Config::Ini::Expanded object to retain the comments that are in the file.
The default is C<0> -- comments are not kept.  This applies to C<new()>,
C<init()>, and C<as_string()>, i.e., C<new()> and C<init()> will load
the comments into the object, and C<as_string()> will output these
comments.

Or you can pass the C<'keep_comments'> parameter to the C<new()> or
C<init()> methods as described above.

=head3 get_comments( $section, $name, $i )

Use C<get_comments()> to return the comments that appear B<above> a
certain name.  Since names may be repeated (forming an array of
values), pass an array index (C<$i>) to identify the comment desired.
If C<$i> is undefined, C<0> is assumed.

 my $comments = $ini->get_comments( $section, $name );

=head3 get_comment( $section, $name, $i )

Use C<get_comment()> (singular) to return the comments that appear
B<on> the same line as a certain name's assignment.  Pass an array
index (C<$i>) to identify the comment desired.  If C<$i> is undefined,
C<0> is assumed.

 $comment = $ini->get_comment( $section, $name );

=head3 set_comments( $section, $name, $i, @comments )

Use C<set_comments()> to specify comments for a given occurrence of a
name.  When C<as_string()> is called, these comments will appear
B<above> the name.

  $ini->set_comments( $section, $name, 0, 'Hello World' );

In an Ini file, comments must begin with C<'#'> or C<';'> and end with
a newline.  If your comments don't, C<'# '> and C<"\n"> will be added.

=head3 set_comment( $section, $name, $i, @comments )

Use C<set_comment()> to specify comments for a given occurrence of a
name.  When C<as_string()> is called, these comments will appear B<on>
the same line as the name's assignment.

  $ini->set_comment( $section, $name, 0, 'Hello World' );

In an Ini file, comments must begin with C<'#'> or C<';'>.  If your
comments don't, C<'# '> will be added.  If you pass an array of
comments, they will be strung together on one line.

=head3 get_section_comments( $section )

Use C<get_section_comments()> to retrieve the comments that appear B<above>
the C<[section]> line, e.g.,

 # Comment 1
 [section] # Comment 2

 # $comments eq "# Comment 1\n"
 my $comments = $ini->get_section_comments( $section );

=head3 get_section_comment( $section )

Use C<get_section_comment()> (note: singular 'comment') to retrieve the
comment that appears B<on> the same line as the C<[section]> line.

 # Comment 1
 [section] # Comment 2

 # $comment eq " # Comment 2\n"
 my $comment = $ini->get_section_comment( $section );

=head3 set_section_comments( $section, @comments )

Use C<set_section_comments()> to set the value of the comments above
the C<[section]> line.

 $ini->set_section_comments( $section, $comments );

=head3 set_section_comment( $section, @comments )

Use C<set_section_comment()> (singular) to set the value of the comment
at the end of the C<[section]> line.

 $ini->set_section_comment( $section, $comment );

=head2 Recreating the Ini File Structure

=head3 as_string()

Use C<as_string()> to dump the Config::Ini::Expanded object in an Ini
file format.  If C<$Config::Ini::Expanded::keep_comments> is true, the
comments will be included.

 print INIFILE $ini->as_string();

The value C<as_string()> returns is not guaranteed to be exactly what
was in the original Ini file.  This is particularly true for files
processed by this module, because quoted values may be interpolated
right away.  For this reason, if you need to edit an Ini file, use
the Config::Ini::Edit module.

But barring all that, you can expect the following:

- All sections and names will be retained.

- All values will resolve correctly, i.e., a call to C<get()> will
return the expected value.

- All comments will be present (if C<'keep_comments'> is true).

- As many value attributes as possible will be retained, e.g., quotes,
escapes, indents, etc.  But the C<':parse'> modifier will B<not> be
retained.

- If the same section appears multiple times in a file, all of its
options will be output in only one occurrence of that section, in the
position of the original first occurrence.  E.g.,

 [section1]
 name1 = value
 [section2]
 name2 = value
 [section1]
 name3 = value

will be output as

 [section1]
 name1 = value
 name3 = value
 
 [section2]
 name2 = value

(Note that as_string() inserts a blank line between sections if there
is not a comment there.)

- If the same name appears multiple times in a section, all of its
occurrences will be grouped together, at the same position as the first
occurrence.  E.g.,

 [section]
 name1 = value1
 name2 = value2
 name1 = another

will be output as

 [section]
 name1 = value1
 name1 = another
 name2 = value2

=head1 SEE ALSO

Config::Ini,
Config::Ini::Edit
Config::Ini::Quote,
Config::IniFiles,
Config:: ... (many others)

=head1 AUTHOR

Brad Baxter, E<lt>bmb@mail.libs.uga.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Brad Baxter

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
