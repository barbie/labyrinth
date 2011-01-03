package Labyrinth::MLUtils;

use strict;
use warnings;
use utf8;

use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT @EXPORT_OK);
$VERSION = '5.02';

=head1 NAME

Labyrinth::MLUtils - Standard Database Access Methods

=head1 SYNOPSIS

  use Labyrinth::MLUtils;

=cut

# -------------------------------------
# Export Details

require Exporter;
@ISA = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw(
        LegalTag LegalTags CleanTags
        CleanHTML SafeHTML CleanLink CleanWords
        DropDownList DropDownListText
        DropDownRows DropDownRowsText
        DropDownMultiList DropDownMultiRows
        ErrorText ErrorSymbol
        LinkSpam

        create_inline_styles
        demoroniser
        process_html escape_html
) ] );

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = ( @{ $EXPORT_TAGS{'all'} } );

# -------------------------------------
# Library Modules

use Regexp::Common  qw /profanity/;
use Encode::ZapCP1252;

use Labyrinth::Variables;

# -------------------------------------
# Variables

my $DEFAULTTAGS = 'p,a,br,b,strong,center,hr,ol,ul,li,i,img,em,strike,h1,h2,h3,h4,h5,h6,table,thead,tr,th,tbody,td,sup,address';
my ($HTMLTAGS,%HTMLTAGS);

# -------------------------------------
# The Public Interface Subs

=head1 FUNCTIONS

=head2 HTML Tag handling

=over 4

=item LegalTag

Returns TRUE or FALSE as to whether the given HTML tag is accepted by the
system.

=item LegalTags

Returns the list of HTML tags that are accepted by the system.

=item CleanTags

For a given text string, attempts to clean the use of any HTML tags. Any HTML
tags found that are not accepted by the system are encoded into HTML entities.

=item CleanHTML

For a given text string, removes all existence of any HTML tag. Mostly used in
input text box cleaning.

=item SafeHTML

For a given text string, encodes all HTML tags to HTML entities. Mostly used in
input textarea edit preparation.

=item CleanLink

=item CleanWords

=back

=cut

sub LegalTag {
    my $tag = lc shift;

    my %tags = _buildtags();
    return 1    if($tags{$tag});
    return 0;
}

sub LegalTags {
    my %tags = _buildtags();
    my $tags = join(", ", sort keys %tags);
    $tags =~ s/, ([^,]+)$/ and $1/;
    return $tags;
}

sub CleanTags {
    my $text = shift;
    return ''   unless($text);

    $text =~ s!</?(span|tbody)[^>]*>!!sig;
    $text =~ s!<(br|hr)>!<$1 />!sig;
    $text =~ s!<p>(?:\s|&nbsp;)+(?:</p>)?<(table|p|ul|ol|div|pre)!<$1!sig;
    $text =~ s!\s+&\s+! &amp; !sg;
    $text =~ s!&[lr]squo;!&quot;!mg;
    $text =~ s{&(?!\#\d+;|[a-z0-9]+;)}{&amp;}sig;

    my %tags = _buildtags();
    my @found = ($text =~ m!</?(\w+)(?:\s+[^>]*)?>!gm);
    for my $tag (@found) {
        $tag = lc $tag;
        next    if($tags{$tag});

        $text =~ s!<(/?$tag(?:[^>]*)?)>!&lt;$1&gt;!igm;
        $tags{$tag} = 1;
    }

    process_html($text,0,1);
}

sub CleanHTML {
    my $text = shift;
    return ''   unless($text);

    $text =~ s!<[^>]+>!!gm; # remove any tags
    $text =~ s!\s{2,}! !mg;
    $text =~ s!&[lr]squo;!&quot;!mg;
    $text =~ s{&(?!\#\d+;|[a-z0-9]+;)}{&amp;}sig;

    process_html($text,0,0);
}

sub SafeHTML {
    my $text = shift;
    return ''   unless($text);

    $text =~ s!<!&lt;!gm;
    $text =~ s!>!&gt;!gm;
    $text =~ s!\s+&\s+! &amp; !mg;
    $text =~ s!&[lr]squo;!&quot;!mg;
    $text =~ s{&(?!\#\d+;|[a-z0-9]+;)}{&amp;}sig;

    process_html($text,0,0);
}

sub CleanLink {
    my $text = shift;
    return ''   unless($text);

    # remove anything that looks like a link
    $text =~ s!https?://[^\s]*!!gis;
    $text =~ s!<a.*?/a>!!gis;
    $text =~ s!\[url.*?url\]!!gis;
    $text =~ s!\[link.*?link\]!!gis;
#    $text =~ s!$settings{urlregex}!!gis;

    CleanTags($text);
}

sub CleanWords {
    my $text = shift;

    $text =~ s/$RE{profanity}//gis;
    my $filter = join("|", map {$_->[1]} $dbi->GetQuery('array','AllBadWords'));
    $text =~ s/$filter//gis;

    return $text;
}

sub _buildtags {
    return %HTMLTAGS    if(%HTMLTAGS);

    if(defined $settings{htmltags} && $settings{htmltags} =~ /^\+(.*)/) {
        $settings{htmltags} = $1 . ',' . $DEFAULTTAGS;
    } elsif(!$settings{htmltags}) {
        $settings{htmltags} = $DEFAULTTAGS;
    }

    %HTMLTAGS = map {$_ => 1} split(",",$settings{htmltags});
    return %HTMLTAGS;
}

=head2 Drop Down Boxes

=over 4

=item DropDownList

=item DropDownListText

=item DropDownRows

=item DropDownRowsText

=item DropDownMultiList

=item DropDownMultiRows

=back

=cut

sub DropDownList {
    my ($opt,$name,@items) = @_;

    return  qq|<select name="$name">| .
            join("",(map { qq|<option value="$_"|.
                    (defined $opt && $opt == $_ ? ' selected="selected"' : '').
                    ">$_</option>" } @items)) .
            "</select>\n";
}

sub DropDownListText {
    my ($opt,$name,@items) = @_;

    return  qq|<select name="$name">| .
            join("",(map { qq|<option value="$_"|.
                    (defined $opt && $opt eq $_ ? ' selected="selected"' : '').
                    ">$_</option>" } @items)) .
            "</select>\n";
}

sub DropDownRows {
    my ($opt,$name,$index,$value,@items) = @_;

    return  qq|<select name="$name">| .
            join("",(map { qq|<option value="$_->{$index}"|.
                    (defined $opt && $opt == $_->{$index} ? ' selected="selected"' : '').
                    ">$_->{$value}</option>" } @items)) .
            "</select>\n";
}

sub DropDownRowsText {
    my ($opt,$name,$index,$value,@items) = @_;

    return  qq|<select name="$name">| .
            join("",(map { qq|<option value="$_->{$index}"|.
                    (defined $opt && $opt eq $_->{$index} ? ' selected="selected"' : '').
                    ">$_->{$value}</option>" } @items)) .
            "</select>\n";
}

sub DropDownMultiList {
    my ($opts,$name,$count,@items) = @_;
    my %opts;

    if(defined $opts) {
        if(ref($opts) eq 'ARRAY') {
            %opts = map {$_ => 1} @$opts;
        } elsif($opts =~ /,/) {
            %opts = map {$_ => 1} split(/,/,$opts);
        } elsif($opts) {
            %opts = ("$opts" => 1);
        }
    }

    return  qq|<select name="$name" multiple="multiple" size="$count">| .
            join("",(map { qq|<option value="$_"|.
                    (defined $opts && $opts{$_} ? ' selected="selected"' : '').
                    ">$_</option>" } @items)) .
            "</select>\n";
}

sub DropDownMultiRows {
    my ($opts,$name,$index,$value,$count,@items) = @_;
    my %opts;

    if(defined $opts) {
        if(ref($opts) eq 'ARRAY') {
            %opts = map {$_ => 1} @$opts;
        } elsif($opts =~ /,/) {
            %opts = map {$_ => 1} split(/,/,$opts);
        } elsif($opts) {
            %opts = ("$opts" => 1);
        }
    }

    return  qq|<select name="$name" multiple="multiple" size="$count">| .
            join("",(map { qq|<option value="$_->{$index}"|.
                    (defined $opts && $opts{$_->{$index}} ? ' selected="selected"' : '').
                    ">$_->{$value}</option>" } @items)) .
            "</select>\n";
}

=head2 Error Functions

=over 4

=item ErrorText

Returns the given error string in a HTML span tag (bold red font).

=item ErrorSymbol

Flags to the system that an error has occured and returns the HTML symbol for
'empty' which can then be used as the error field indicator.

=back

=cut

sub ErrorText {
    my $text = shift;
    return qq!<span style="color:red;font-weight:bold">$text</span>!;
}

sub ErrorSymbol {
    $tvars{errmess} = 1;
    $tvars{errcode} = 'ERROR';
    return '&#8709;';
}

=head2 Protection Functions

=over 4

=item LinkSpam

Checks whether any links exist in the given text that could indicate comment spam.

=back

=cut

sub LinkSpam {
    my $text = shift;
    return 1   if($text =~ m!https?://[^\s]*!is);
    return 1   if($text =~ m!<a.*?/a>!is);
    return 1   if($text =~ m!\[url.*?url\]!is);
    return 1   if($text =~ m!\[link.*?link\]!is);
    return 1   if($text =~ m!$settings{urlregex}!is);
    return 0;
}

=head2 CSS Handling Code

=over 4

=item create_inline_styles ( HASHREF )

=back

=cut

sub create_inline_styles {
    my $hash = shift;

    my $text = qq|<style type="text/css" media="screen">\n|;
    for(sort keys %$hash) {
        $text .= qq|$_ {\n|;
        for my $attr (keys %{$hash->{$_}}) {
            $text .= qq|\t$attr: $hash->{$_}->{$attr};\n|
        }
        $text .= qq|}\n|;
    }
    $text .= qq|</style>\n|;
    return $text;
}

=head2 HTML Demoroniser Code

=over 4

=item demoroniser ( INPUT )

Given a string, with replace the Microsoft "smart" characters with sensible
ACSII versions.

=back

=cut

sub demoroniser {
	my $str	= shift;

	zap_cp1252($str);

	$str =~ s/\xE2\x80\x9A/,/g;		# 82
	$str =~ s/\xE2\x80\x9E/,,/g;	# 84
	$str =~ s/\xE2\x80\xA6/.../g;	# 85

	$str =~ s/\xCB\x86/^/g;			# 88

	$str =~ s/\xE2\x80\x98/`/g;		# 91
	$str =~ s/\xE2\x80\x99/'/g;		# 92
	$str =~ s/\xE2\x80\x9C/"/g;		# 93
	$str =~ s/\xE2\x80\x9D/"/g;		# 94
	$str =~ s/\xE2\x80\xA2/*/g;		# 95
	$str =~ s/\xE2\x80\x93/-/g;		# 96
	$str =~ s/\xE2\x80\x94/-/g;		# 97

	$str =~ s/\xE2\x80\xB9/</g;		# 8B
	$str =~ s/\xE2\x80\xBA/>/g;		# 9B

	return $str;
}

=head2 HTML Handling Code

=over 4

=item process_html ( INPUT [,LINE_BREAKS [,ALLOW]] )

=item escape_html ( INPUT )

=item unescape_html ( INPUT )

=item cleanup_attr_style

=item cleanup_attr_number

=item cleanup_attr_multilength

=item cleanup_attr_text

=item cleanup_attr_length

=item cleanup_attr_color

=item cleanup_attr_uri

=item cleanup_attr_tframe

=item cleanup_attr_trules

=item cleanup_html

=item cleanup_tag

=item cleanup_close

=item cleanup_cdata

=item cleanup_no_number

=item check_url_valid

=item cleanup_attr_inputtype

=item cleanup_attr_method

=item cleanup_attr_scriptlang

=item cleanup_attr_scripttype

=item strip_nonprintable

=back

=cut

# Configuration
my $allow_html  = 0;
my $line_breaks = 1;
# End configuration

##################################################################
#
# HTML handling code
#
# The code below provides some functions for manipulating HTML.
#
#  process_html ( INPUT [,LINE_BREAKS [,ALLOW]] )
#
#    Returns a modified version of the HTML string INPUT, with
#    any potentially malicious HTML constructs (such as java,
#    javascript and IMG tags) removed.
#
#    If the LINE_BREAKS parameter is present and true then
#    line breaks in the input will be converted to html <br />
#    tags in the output.
#
#    If the ALLOW parameter is present and true then most
#    harmless tags will be left in, otherwise all tags will be
#    removed.
#
#  escape_html ( INPUT )
#
#    Returns a copy of the string INPUT with any HTML
#    metacharacters replaced with character escapes.
#
#  unescape_html ( INPUT )
#
#    Returns a copy of the string INPUT with HTML character
#    entities converted to literal characters where possible.
#    Note that some entites have no 8-bit character equivalent,
#    see "http://www.w3.org/TR/xhtml1/DTD/xhtml-symbol.ent"
#    for some examples.  unescape_html() leaves these entities
#    in their encoded form.
#

use vars qw(%html_entities $html_safe_chars %escape_html_map);
use vars qw(%safe_tags %safe_style %tag_is_empty %closetag_is_optional
            %closetag_is_dependent %force_closetag %transpose_tag 
            $convert_nl %auto_deinterleave $auto_deinterleave_pattern);

# check the validity of a URL.

sub process_html {
    my ($text, $line_breaks, $allow_html) = @_;
    $text =~ s!</pre><pre>!<br />!gs;

    # clean text of any nasties
    #$text =~ s/[\x201A\x2018\x2019`]/&#39;/g;   # nasty single quotes
    #$text =~ s/[\x201E\x201C\x201D]/&quot;/g;   # nasty double quotes

    cleanup_html( $text, $line_breaks, ($allow_html ? \%safe_tags : {}));
}

BEGIN
{
    %html_entities = (
        'lt'     => '<',
        'gt'     => '>',
        'quot'   => '"',
        'amp'    => '&',

        'nbsp'   => "\240", 'iexcl'  => "\241",
        'cent'   => "\242", 'pound'  => "\243",
        'curren' => "\244", 'yen'    => "\245",
        'brvbar' => "\246", 'sect'   => "\247",
        'uml'    => "\250", 'copy'   => "\251",
        'ordf'   => "\252", 'laquo'  => "\253",
        'not'    => "\254", 'shy'    => "\255",
        'reg'    => "\256", 'macr'   => "\257",
        'deg'    => "\260", 'plusmn' => "\261",
        'sup2'   => "\262", 'sup3'   => "\263",
        'acute'  => "\264", 'micro'  => "\265",
        'para'   => "\266", 'middot' => "\267",
        'cedil'  => "\270", 'supl'   => "\271",
        'ordm'   => "\272", 'raquo'  => "\273",
        'frac14' => "\274", 'frac12' => "\275",
        'frac34' => "\276", 'iquest' => "\277",

        'Agrave' => "\300", 'Aacute' => "\301",
        'Acirc'  => "\302", 'Atilde' => "\303",
        'Auml'   => "\304", 'Aring'  => "\305",
        'AElig'  => "\306", 'Ccedil' => "\307",
        'Egrave' => "\310", 'Eacute' => "\311",
        'Ecirc'  => "\312", 'Euml'   => "\313",
        'Igrave' => "\314", 'Iacute' => "\315",
        'Icirc'  => "\316", 'Iuml'   => "\317",
        'ETH'    => "\320", 'Ntilde' => "\321",
        'Ograve' => "\322", 'Oacute' => "\323",
        'Ocirc'  => "\324", 'Otilde' => "\325",
        'Ouml'   => "\326", 'times'  => "\327",
        'Oslash' => "\330", 'Ugrave' => "\331",
        'Uacute' => "\332", 'Ucirc'  => "\333",
        'Uuml'   => "\334", 'Yacute' => "\335",
        'THORN'  => "\336", 'szlig'  => "\337",

        'agrave' => "\340", 'aacute' => "\341",
        'acirc'  => "\342", 'atilde' => "\343",
        'auml'   => "\344", 'aring'  => "\345",
        'aelig'  => "\346", 'ccedil' => "\347",
        'egrave' => "\350", 'eacute' => "\351",
        'ecirc'  => "\352", 'euml'   => "\353",
        'igrave' => "\354", 'iacute' => "\355",
        'icirc'  => "\356", 'iuml'   => "\357",
        'eth'    => "\360", 'ntilde' => "\361",
        'ograve' => "\362", 'oacute' => "\363",
        'ocirc'  => "\364", 'otilde' => "\365",
        'ouml'   => "\366", 'divide' => "\367",
        'oslash' => "\370", 'ugrave' => "\371",
        'uacute' => "\372", 'ucirc'  => "\373",
        'uuml'   => "\374", 'yacute' => "\375",
        'thorn'  => "\376", 'yuml'   => "\377",
    );

    #
    # Build a map for representing characters in HTML.
    #
    $html_safe_chars = '()[]{}/?.,\\|;:@#~=+-_*^%$! ' . "\'\r\n\t";
    %escape_html_map =
        map {$_,$_} ( 'A'..'Z', 'a'..'z', '0'..'9',
        split(//, $html_safe_chars)
        );
    foreach my $ent (keys %html_entities) {
        $escape_html_map{$html_entities{$ent}} = "&$ent;";
    }
    foreach my $c (0..255) {
        unless ( exists $escape_html_map{chr $c} ) {
        $escape_html_map{chr $c} = sprintf '&#%d;', $c;
    }
}

#
# Tables for use by cleanup_html() (below).
#
# The main table is %safe_tags, which is a hash by tag name of
# all the tags that it's safe to leave in.  The value for each
# tag is another hash, and each key of that hash defines an
# attribute that the tag is allowed to have.
#
# The values in the tag attribute hash can be undef (for an
# attribute that takes no value, for example the nowrap
# attribute in the tag <td align="left" nowrap>) or they can
# be coderefs pointing to subs for cleaning up the attribute
# values.
#
# These subs will called with the attribute value in $_, and
# they can return either a cleaned attribute value or undef.
# If undef is returned then the attribute will be deleted
# from the tag.
#
# The list of tags and attributes was taken from
# "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
#
# The %tag_is_empty table defines the set of tags that have
# no corresponding close tag.
#
# cleanup_html() moves close tags around to force all tags to
# be closed in the correct sequence.  For example, the text
# "<h1><i>foo</h1>bar</i>" will be converted to the text
# "<h1><i>foo</i></h1>bar".
#
# The %auto_deinterleave table defines the set of tags which
# should be automatically reopened if they're closed early
# in this way.  All the tags involved must be in
# %auto_deinterleave for the tag to be reopened.  For example,
# the text "<b>bb<i>bi</b>ii</i>" will be converted into the
# text "<b>bb<i>bi</i></b><i>ii</i>" rather than into the
# text "<b>bb<i>bi</i></b>ii", because *both* "b" and "i" are
# in %auto_deinterleave.
#
    %tag_is_empty = (
        'hr' => 1, 'link' => 1, 'param' => 1, 'img'      => 1,
        'br' => 1, 'area' => 1, 'input' => 1, 'basefont' => 1
    );
    %closetag_is_optional = ( );
    %closetag_is_dependent = ( );
    %force_closetag = (
        'pre'   => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'p'     => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'h1'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'h2'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'h3'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'h4'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'h5'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'h6'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'table' => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'pre' => 1, 'ul' => 1, 'ol' => 1 },
        'ul'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1 },
        'ol'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1 },
        'li'    => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1, 'li' => 1 },
        'form'  => { 'p' => 1, 'h1' => 1, 'h2' => 1, 'h3' => 1, 'h4' => 1, 'h5' => 1, 'h6' => 1 },
    );
    %transpose_tag = ( 'b' => 'strong', 'u' => 'em' );
    %auto_deinterleave = map {$_,1} qw(
        tt i b big small u s strike font basefont
        em strong dfn code q sub sup samp kbd var
        cite abbr acronym span
    );
    $auto_deinterleave_pattern = join '|', keys %auto_deinterleave;
    my %attr = (
        'style' => \&cleanup_attr_style,
        'name'  => \&cleanup_attr_text,
        'id'    => \&cleanup_attr_text,
        'class' => \&cleanup_attr_text,
        'title' => \&cleanup_attr_text,
        'onmouseover'   => \&cleanup_attr_text,
        'onmouseout'    => \&cleanup_attr_text,
        'onclick'       => \&cleanup_attr_text,
        'onfocus'       => \&cleanup_attr_text,
        'ondblclick'    => \&cleanup_attr_text,
    );
    my %font_attr = (
        %attr,
        size  => sub { /^([-+]?\d{1,3})$/    ? $1 : undef },
        face  => sub { /^([\w\-, ]{2,100})$/ ? $1 : undef },
        color => \&cleanup_attr_color,
    );
    my %insdel_attr = (
        %attr,
        'cite'     => \&cleanup_attr_uri,
        'datetime' => \&cleanup_attr_text,
    );
    my %texta_attr = (
        %attr,
        align => sub { s/middle/center/i;
            /^(left|center|right|justify)$/i ? lc $1 : undef
        },
    );
    my %cellha_attr = (
        align   => sub { s/middle/center/i;
            /^(left|center|right|justify|char)$/i
            ? lc $1 : undef
        },
        char    => sub { /^([\w\-])$/ ? $1 : undef },
        charoff => \&cleanup_attr_length,
    );
    my %cellva_attr = (
        valign => sub { s/center/middle/i;
            /^(top|middle|bottom|baseline)$/i ? lc $1 : undef
        },
    );
    my %cellhv_attr = ( %attr, %cellha_attr, %cellva_attr );
    my %col_attr = (
        %attr,
        width => \&cleanup_attr_multilength,
        span =>  \&cleanup_attr_number,
        %cellhv_attr,
    );
    my %thtd_attr = (
        %attr,
        abbr    => \&cleanup_attr_text,
        axis    => \&cleanup_attr_text,
        headers => \&cleanup_attr_text,
        scope   => sub { /^(row|col|rowgroup|colgroup)$/i ? lc $1 : undef },
        rowspan => \&cleanup_attr_number,
        colspan => \&cleanup_attr_number,
        %cellhv_attr,
        nowrap  => undef,
        bgcolor => \&cleanup_attr_color,
        width   => \&cleanup_attr_number,
        height  => \&cleanup_attr_number,
    );
    my $none = {};
    %safe_tags = (
        # FORM CONTROLS
        'form'       => { %attr,
                'method'    => \&cleanup_attr_method,
                'action'    => \&cleanup_attr_text,
                'enctype'   => \&cleanup_attr_text,
                'onsubmit'  => \&cleanup_attr_text,
        },
        'button'     => { %attr,
                'type'      => \&cleanup_attr_inputtype,
        },
        'input'      => { %attr,
                'type'      => \&cleanup_attr_inputtype,
                'size'      => \&cleanup_attr_number,
                'maxlength'	=> \&cleanup_attr_number,
                'value'     => \&cleanup_attr_text,
                'checked'   => \&cleanup_attr_text,
                'readonly'  => \&cleanup_attr_text,
                'disabled'  => \&cleanup_attr_text,
                'src'       => \&cleanup_attr_uri,
                'width'     => \&cleanup_attr_length,
                'height'    => \&cleanup_attr_length,
                'alt'       => \&cleanup_attr_text,
                'onchange'  => \&cleanup_attr_text,
        },
        'select'     => { %attr,
                'size'      => \&cleanup_attr_number,
                'title'     => \&cleanup_attr_text,
                'value'     => \&cleanup_attr_text,
                'multiple'  => \&cleanup_attr_text,
                'disabled'  => \&cleanup_attr_text,
                'onchange'  => \&cleanup_attr_text,
        },
        'option'     => { %attr,
                'value'     => \&cleanup_attr_text,
                'selected'  => \&cleanup_attr_text,
        },
        'textarea'   => { %attr,
                'rows'      => \&cleanup_attr_number,
                'cols'      => \&cleanup_attr_number,
        },

        # LAYOUT STYLE
        'style'     => {
                'type'      => \&cleanup_attr_text,
        },
        'br'         => { 'clear' => sub { /^(left|right|all|none)$/i ? lc $1 : undef }
        },
        'hr'         => \%attr,
        'em'         => \%attr,
        'strong'     => \%attr,
        'dfn'        => \%attr,
        'code'       => \%attr,
        'samp'       => \%attr,
        'kbd'        => \%attr,
        'var'        => \%attr,
        'cite'       => \%attr,
        'abbr'       => \%attr,
        'acronym'    => \%attr,
        'q'          => { %attr, 'cite' => \&cleanup_attr_uri },
        'blockquote' => { %attr, 'cite' => \&cleanup_attr_uri },
        'sub'        => \%attr,
        'sup'        => \%attr,
        'tt'         => \%attr,
        'i'          => \%attr,
        'b'          => \%attr,
        'big'        => \%attr,
        'small'      => \%attr,
        'u'          => \%attr,
        's'          => \%attr,
        'font'       => \%font_attr,
        'h1'         => \%texta_attr,
        'h2'         => \%texta_attr,
        'h3'         => \%texta_attr,
        'h4'         => \%texta_attr,
        'h5'         => \%texta_attr,
        'h6'         => \%texta_attr,
        'p'          => \%texta_attr,
        'div'        => \%texta_attr,
        'span'       => \%texta_attr,
        'ul'         => { %attr,
                'type'    => sub { /^(disc|square|circle)$/i ? lc $1 : undef },
                'compact' => undef,
        },
        'ol'         => { %attr,
                'type'    => \&cleanup_attr_text,
                'compact' => undef,
                'start'   => \&cleanup_attr_number,
        },
        'li'         => { %attr,
                'type'  => \&cleanup_attr_text,
                'value' => \&cleanup_no_number,
        },
        'dl'         => { %attr, 'compact' => undef },
        'dt'         => \%attr,
        'dd'         => \%attr,
        'address'    => \%attr,
        'pre'        => { %attr, 'width' => \&cleanup_attr_number },
        'center'     => \%attr,
        'nobr'       => $none,

        # FUNCTIONAL TAGS
        'iframe'     => { %attr,
                'src'       => \&cleanup_attr_uri,
                'width'     => \&cleanup_attr_length,
                'height'    => \&cleanup_attr_length,
                'border'    => \&cleanup_attr_number,
                'alt'       => \&cleanup_attr_text,
                'align'     => sub { s/middle/center/i;
                                    /^(left|center|right)$/i ? lc $1 : undef
                },
                'title'     => \&cleanup_attr_text,
        },
        'img'        => { %attr,
                'src'       => \&cleanup_attr_uri,
                'width'     => \&cleanup_attr_length,
                'height'    => \&cleanup_attr_length,
                'border'    => \&cleanup_attr_number,
                'alt'       => \&cleanup_attr_text,
                'align'     => sub { s/middle/center/i;
                                    /^(left|center|right)$/i ? lc $1 : undef
                },
                'title'     => \&cleanup_attr_text,
                'usemap'    => \&cleanup_attr_text,
        },
        'map'        => { %attr,
        },
        'area'       => { %attr,
                'shape'     => \&cleanup_attr_text,
                'coords'    => \&cleanup_attr_text,
                'href'      => \&cleanup_attr_uri,
        },
        'table'      => { %attr,
                'frame'       => \&cleanup_attr_tframe,
                'rules'       => \&cleanup_attr_trules,
                %texta_attr,
                'bgcolor'     => \&cleanup_attr_color,
                'width'       => \&cleanup_attr_length,
                'cellspacing' => \&cleanup_attr_length,
                'cellpadding' => \&cleanup_attr_length,
                'border'      => \&cleanup_attr_number,
                'summary'     => \&cleanup_attr_text,
        },
        'caption'    => { %attr,
                'align' => sub { /^(top|bottom|left|right)$/i ? lc $1 : undef },
        },
        'colgroup'   => \%col_attr,
        'col'        => \%col_attr,
        'thead'      => \%cellhv_attr,
        'tfoot'      => \%cellhv_attr,
        'tbody'      => \%cellhv_attr,
        'tr'         => { %attr,
                bgcolor => \&cleanup_attr_color,
                %cellhv_attr,
        },
        'th'         => \%thtd_attr,
        'td'         => \%thtd_attr,
        'ins'        => \%insdel_attr,
        'del'        => \%insdel_attr,
        'a'          => { %attr,
                href    => \&cleanup_attr_uri,
                style   => \&cleanup_attr_text,
                target  => \&cleanup_attr_text,
                rel     => \&cleanup_attr_text,
        },

        'script'     => {
                language => \&cleanup_attr_scriptlang,
                type     => \&cleanup_attr_scripttype,
                src      => \&cleanup_attr_uri,
        },
        'noscript'   => { %attr,
        },
        'link'       => { %attr,
                href        => \&cleanup_attr_uri,
                'rel'       => \&cleanup_attr_text,
                'type'      => \&cleanup_attr_text,
                'media'     => \&cleanup_attr_text,
        },
        'object'     => { %attr,
                'width'     => \&cleanup_attr_length,
                'height'    => \&cleanup_attr_length,
                style       => \&cleanup_attr_text,
                type        => \&cleanup_attr_text,
                data        => \&cleanup_attr_text,
                classid     => \&cleanup_attr_text,
                codebase    => \&cleanup_attr_text,
        },
        'param'     => {
                name    => \&cleanup_attr_text,
                value   => \&cleanup_attr_text,
        },
        'embed'     => { %attr,
                'src'               => \&cleanup_attr_uri,
                'bgcolor'           => \&cleanup_attr_color,
                'width'             => \&cleanup_attr_length,
                'height'            => \&cleanup_attr_length,
                'pluginspage'       => \&cleanup_attr_uri,
                flashvars           => \&cleanup_attr_text,
                type                => \&cleanup_attr_text,
                quality             => \&cleanup_attr_text,
                allowScriptAccess   => \&cleanup_attr_text,
                allowNetworking     => \&cleanup_attr_text,
        },
    );
    %safe_style = (
        'color'             => \&cleanup_attr_color,
        'border-color'      => \&cleanup_attr_color,
        'background-color'  => \&cleanup_attr_color,
        'padding'           => \&cleanup_attr_text,
        'margin'            => \&cleanup_attr_text,
        'border'            => \&cleanup_attr_text,
        'visibility'        => \&cleanup_attr_text,
        # XXX TODO: the CSS spec defines loads more, add 'em
    );
}

        use Labyrinth::Audit;

sub cleanup_attr_style {
    my @clean = ();
    foreach my $elt (split /;/, $_) {
        next if $elt =~ m#^\s*$#;
        if ( $elt =~ m#^\s*([\w\-]+)\s*:\s*(.+?)\s*$#s ) {
            my ($key, $val) = (lc $1, $2);
            local $_ = $val;
            my $sub = $safe_style{$key};
            if (defined $sub) {
                my $cleanval = &{$sub}();
                if (defined $cleanval) {
                    push @clean, "$key:$val";
                }
            }
        }
    }
    return join '; ', @clean;
}
sub cleanup_attr_number {
    /^(\d+)$/ ? $1 : undef;
}
sub cleanup_attr_method {
    /^(get|post)$/i ? lc $1 : 'post';
}
sub cleanup_attr_inputtype {
    /^(text|password|checkbox|radio|submit|reset|file|hidden|image|button)$/ ? $1 : undef;
}
sub cleanup_attr_multilength {
    /^(\d+(?:\.\d+)?[*%]?)$/ ? $1 : undef;
}
sub cleanup_attr_text {
    tr/-a-zA-Z0-9_()[]{}\/?.,\\|;:&@#~=+*^%$'! \xc0-\xff//dc;
    $_;
}
sub cleanup_attr_length {
    /^(\d+\%?)$/ ? $1 : undef;
}
sub cleanup_attr_color {
    /^(\w{2,20}|#[\da-fA-F]{6})$/ or die "color <<$_>> bad";
    /^(\w{2,20}|#[\da-fA-F]{6})$/ ? $1 : undef;
}
sub cleanup_attr_uri {
    check_url_valid($_) ? $_ : undef;
}
sub cleanup_attr_tframe {
    /^(void|above|below|hsides|lhs|rhs|vsides|box|border)$/i
    ? lc $1 : undef;
}
sub cleanup_attr_trules {
    /^(none|groups|rows|cols|all)$/i ? lc $1 : undef;
}

sub cleanup_attr_scriptlang {
    /^(javascript)$/i ? lc $1 : undef;
}
sub cleanup_attr_scripttype {
    /^(text\/javascript)$/i ? lc $1 : undef;
}

use vars qw(@stack $safe_tags $convert_nl);
sub cleanup_html {
    local ($_, $convert_nl, $safe_tags) = @_;
    local @stack = ();

    my $ignore_comments = 0;
    if($ignore_comments) {
        s[
            (?: <!--.*?-->                                   ) |
            (?: <[?!].*?>                                    ) |
            (?: <([a-z0-9]+)\b((?:[^>'"]|"[^"]*"|'[^']*')*)> ) |
            (?: </([a-z0-9]+)>                               ) |
            (?: (.[^<]*)                                     )
        ][
            defined $1 ? cleanup_tag(lc $1, $2)              :
            defined $3 ? cleanup_close(lc $3)                :
            defined $4 ? cleanup_cdata($4)                   :
            ''
        ]igesx;
    } else {
        s[
            (?: (<!--.if.*?endif.-->)                        ) |
            (?: <!--.*?-->                                   ) |
            (?: <[?!].*?>                                    ) |
            (?: <([a-z0-9]+)\b((?:[^>'"]|"[^"]*"|'[^']*')*)> ) |
            (?: </([a-z0-9]+)>                               ) |
            (?: (.[^<]*)                                     )
        ][
            defined $1 ? $1                                  :
            defined $2 ? cleanup_tag(lc $2, $3)              :
            defined $4 ? cleanup_close(lc $4)                :
            defined $5 ? cleanup_cdata($5)                   :
            ''
        ]igesx;
    }

    # Close anything that was left open
    $_ .= join '', map "</$_->{NAME}>", @stack;

    # Where we turned <i><b>foo</i></b> into <i><b>foo</b></i><b></b>,
    # take out the pointless <b></b>.
    1 while s#<($auto_deinterleave_pattern)\b[^>]*>(&nbsp;|\s)*</\1>##go;

    # cleanup p elements
    s!\s+</p>!</p>!g;
    s!<p></p>!!g;

    # Element pre is not declared in p list of possible children
    s!<p>\s*(<pre>.*?</pre>)\s*</p>!$1!g;

    return $_;
}

sub cleanup_tag
{
    my ($tag, $attrs) = @_;
    unless (exists $safe_tags->{$tag}) {
        return '';
    }

    # for XHTML conformity
    $tag = $transpose_tag{$tag} if($transpose_tag{$tag});

    my $html = '';
    if($force_closetag{$tag}) {
        while (scalar @stack and $force_closetag{$tag}{$stack[0]{NAME}}) {
            $html = cleanup_close($stack[0]{NAME});
        }
    }

    my $t = $safe_tags->{$tag};
    my $safe_attrs = '';
    while ($attrs =~ s#^\s*(\w+)(?:\s*=\s*(?:([^"'>\s]+)|"([^"]*)"|'([^']*)'))?##) {
        my $attr = lc $1;
        my $val = ( defined $2 ? $2                :
                    defined $3 ? unescape_html($3) :
                    defined $4 ? unescape_html($4) :
                    '$attr'
        );
        unless (exists $t->{$attr}) {
            next;
        }
        if (defined $t->{$attr}) {
            local $_ = $val;
            my $cleaned = &{ $t->{$attr} }();
            if (defined $cleaned) {
                $safe_attrs .= qq| $attr="${\( escape_html($cleaned) )}"|;
            }
        } else {
            $safe_attrs .= " $attr";
        }
    }

    if (exists $tag_is_empty{$tag}) {
        return "$html<$tag$safe_attrs />";
    } elsif (exists $closetag_is_optional{$tag}) {
        return "$html<$tag$safe_attrs>";
#   } elsif (exists $closetag_is_dependent{$tag} && $safe_attrs =~ /$closetag_is_dependent{$tag}=/) {
#       return "$html<$tag$safe_attrs />";
    } else {
        my $full = "<$tag$safe_attrs>";
        unshift @stack, { NAME => $tag, FULL => $full };
        return "$html$full";
    }
}

sub cleanup_close {
    my $tag = shift;

    # for XHTML conformity
    $tag = $transpose_tag{$tag} if($transpose_tag{$tag});

    # Ignore a close without an open
    unless (grep {$_->{NAME} eq $tag} @stack) {
        return '';
    }

    # Close open tags up to the matching open
    my @close = ();
    while (scalar @stack and $stack[0]{NAME} ne $tag) {
        push @close, shift @stack;
    }
    push @close, shift @stack;

    my $html = join '', map {"</$_->{NAME}>"} @close;

    # Reopen any we closed early if all that were closed are
    # configured to be auto deinterleaved.
    unless (grep {! exists $auto_deinterleave{$_->{NAME}} } @close) {
        pop @close;
        $html .= join '', map {$_->{FULL}} reverse @close;
        unshift @stack, @close;
    }

    return $html;
}

sub cleanup_cdata {
    local $_ = shift;

    return $_   if(scalar @stack and $stack[0]{NAME} eq 'script');

    s[ (?: & ( [a-zA-Z0-9]{2,15}       |
        [#][0-9]{2,6}           |
        [#][xX][a-fA-F0-9]{2,6} | ) \b ;?
        ) | (.)
    ][
        defined $1 ? "&$1;" : $escape_html_map{$2}
    ]gesx;

    # substitute newlines in the input for html line breaks if required.
    s%\cM?\n%<br />\n%g if $convert_nl;

    return $_;
}

# subroutine to escape the necessary characters to the appropriate HTML
# entities

sub escape_html {
    my $str = shift;
    defined $str or $str = '';
    $str =~ s/([^\w\Q$html_safe_chars\E])/$escape_html_map{$1}/og;
    return $str;
}

# subroutine to unescape escaped HTML entities.  Note that some entites
# have no 8-bit character equivalent, see
# "http://www.w3.org/TR/xhtml1/DTD/xhtml-symbol.ent" for some examples.
# unescape_html() leaves these entities in their encoded form.

sub unescape_html {
    my $str = shift;
    $str =~
    s/ &( (\w+) | [#](\d+) ) \b (;?)
    /
    defined $2 && exists $html_entities{$2} ? $html_entities{$2} :
    defined $3 && $3 > 0 && $3 <= 255       ? chr $3             :
    "&$1$4"
    /gex;

    return strip_nonprintable($str);
}

sub check_url_valid {
  my $url = shift;

  $url = "$tvars{cgipath}/$tvars{script}$url"    if($url =~ /^\?/);

  # allow in page URLs
  return 1 if $url =~ m!^\#!;

  # allow relative URLs with sane values
  return 1 if $url =~ m!^[a-z0-9_\-\.\,\+\/#]+$!i;

  # allow mailto email addresses
  return 1 if $url =~ m#mailto:([-+=\w\'.\&\\//]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)#i;

  # allow javascript calls
  return 1 if $url =~ m#^javascript:#i;

#  $url =~ m< ^ ((?:ftp|http|https):// [\w\-\.]+ (?:\:\d+)?)?
#               (?: /? [\w\-.!~*'(|);/\@+\$,%#]*   )?
#               (?: \? [\w\-.!~*'(|);/\@&=+\$,%#]* )?
#             $
#           >x ? 1 : 0;
  $url =~ m< ^ $settings{urlregex} $ >x ? 1 : 0;
}

sub strip_nonprintable {
  my $text = shift;
  return '' unless defined $text;

  $text=~ tr#\t\n\040-\176\241-\377# #cs;
  return $text;
}

#
# End of HTML handling code
#
##################################################################

1;

__END__

=head1 SEE ALSO

  Labyrinth

=head1 AUTHOR

Barbie, <barbie@missbarbell.co.uk> for
Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2002-2011 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut