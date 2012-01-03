package Labyrinth::Writer;

use warnings;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '5.11';

=head1 NAME

Labyrinth::Writer - Handles the template parsing and output.

=head1 SYNOPSIS

  use Labyrinth::Writer;
  Publish('mytemplate.html');
  PublishCode('MESSAGE');

=head1 DESCRIPTION

The Publish package contains one function, Publish(), which handles
the parsing of a given template with global variables and prints the result.

=head1 EXPORT

  Publish
  PublishCode
  UnPublish
  Transform
  Croak

=cut

# -------------------------------------
# Export Details

require Exporter;
@ISA       = qw( Exporter );
@EXPORT_OK = qw( Publish PublishCode UnPublish Transform Croak );
@EXPORT    = qw( Publish PublishCode UnPublish Transform Croak );

# -------------------------------------
# Library Modules

use File::Basename;
use MIME::Types;

use Labyrinth::Audit;
use Labyrinth::Globals;
use Labyrinth::Variables;
use Labyrinth::MLUtils;

# -------------------------------------
# Variables

my ($PARSER,$RENDER);

my $published;

my %codes = (
    BADLAYOUT       => 'public/badlayout.html',
    BADPAGE         => 'public/badpage.html',
    BADCMD          => 'public/badcommand.html',
    MESSAGE         => 'public/error_message.html',
);

my %binary = (
    pdf             => 'application/pdf'
);

my %knowntypes = (
    html            => 'text/html',
    rss             => 'application/xml',
    xml             => 'application/xml',
    ics             => 'text/calendar',
    txt             => 'text/plain',
    yml             => 'text/yaml',
    yaml            => 'text/yaml'
);

# -------------------------------------
# The Subs

=head1 FUNCTIONS

=over 4

=item Config()

Configure template parser and output method.

=cut

sub Config {
    $settings{'writer-parser'} ||= 'TT';
    $settings{'writer-render'} ||= 'CGI';

    my $parser = 'Labyrinth::Writer::Parser::' . $settings{'writer-parser'};
    my $render = 'Labyrinth::Writer::Render::' . $settings{'writer-render'};

    eval {
        eval "CORE::require $parser";
        $PARSER = $parser->new();
    };
    die "Cannot load Writer::Parser package for '$settings{'writer-parser'}': $@" if($@);

    eval {
        eval "CORE::require $render";
        $RENDER = $render->new();
    };
    die "Cannot load Writer::Render package for '$settings{'writer-render'}': $@" if($@);

}

=item Publish()

Publish() parses a given template, via Template Toolkit, and prints the
result.

=item PublishCode

Publishes a template based on an internal code. Current codes and associated
templates are:

    BADLAYOUT       => 'public/badlayout.html',
    BADPAGE         => 'public/badpage.html',
    BADCMD          => 'public/badcommand.html',
    MESSAGE         => 'public/error_message.html',

TODO: Provide these and more as configurable codes.

=item UnPublish

Used to reset publishing status. Usually only applicable in mod_perl 
environments.

=item Transform

Given a template and a set of variables, parse without publishing the content.

=cut

sub Publish {
    return  if($published);

    Config()    unless($PARSER && $RENDER);

    # redirects require minimal processing
    if($tvars{redirect}) {
        $RENDER->redirect($tvars{redirect});
        $published = 1;
        return;
    }

    # binary files handled directly
    if($tvars{contenttype} && $binary{$tvars{contenttype}}) {
        $tvars{'writer'} = { 'ctype' => $binary{$tvars{'contenttype'}}, 'file' => $tvars{'file'} };
        $RENDER->binary($tvars{'writer'});
        $published = 1;
        return;
    }

    my $path = $settings{'templates'};
    my $vars = \%tvars;

    unless($vars->{'layout'} && -r "$path/$vars->{'layout'}") {
        $vars->{'badlayout'} = $vars->{'layout'};
        $vars->{'layout'} = $codes{BADLAYOUT};
    }
    unless($vars->{'content'} && -r "$path/$vars->{'content'}") {
        $vars->{'badcontent'} = $vars->{'content'};
        $vars->{'content'} = $codes{BADPAGE};
    }
    my $layout = $vars->{'layout'};
    my $content = $vars->{'content'};

#   LogDebug( "layout=[$layout]" );
#   LogDebug( "content=[$content]" );
#   LogDebug( "cookie=[$vars->{cookie}]" )  if($vars->{cookie});
#   use Data::Dumper;
#   LogDebug( "vars=".Dumper($vars) );


    $vars->{evalperl} = ($content eq $codes{BADPAGE} ? 1 : 0);

    #LogDebug("<!-- $layout : $content -->");

    my $output = $PARSER->parser($layout,$vars);

    my ($ext) = $layout =~ m/\.(\w+)$/;
    $ext ||= 'html';

    # split HTML and process etc
    if($ext =~ /htm/) {
        my ($top,$body,$tail) = ($$output =~ m!^(.*?<body[^>]*>)(.*?)(</body>.*)$!si);
#       LogDebug( "html=[$html]" );
#       LogDebug( "top=[$top]" );
#       LogDebug( "tail=[$tail]" );
#       LogDebug( "body=[$body]" );
        my $html = $top . process_html($body,0,1) . $tail;
        $output = \$html;
    }

    $tvars{headers}{type} = $knowntypes{$ext} || do {
        my $types = MIME::Types->new;
        my $mime = $types->mimeTypeOf($ext);
        $mime->type || 'text/html';
    };

    $tvars{headers}{'status'}     = '404 Page Not Found'    if($content eq $codes{BADPAGE} || $content eq $codes{BADCMD});
    $tvars{headers}{'cookie'}     = $tvars{cookie}          if($tvars{cookie});
    $tvars{headers}{'attachment'} = basename($content)      if($layout =~ /\.ics$/);

    $published = 1;

    return $RENDER->publish($tvars{headers}, $output);
}

sub PublishCode {
    $tvars{'content'} = $codes{$_[0]};
    return Publish();
}

sub UnPublish {
    $published = 0;
}

sub Transform {
    my ($template,$vars) = @_;

    my $path = $settings{'templates'};
    my $layout = "$path/$template";

    die "Missing template [$layout]\n"  unless(-e $layout);

    Config()    unless($PARSER && $RENDER);

    my $output = $PARSER->parser($layout,$vars);
    return $$output;
}

=item Croak

A shorthand call to publish and record errors.

=cut

sub Croak {
    my $errmess = join(" ",@_);
    LogError($errmess);
    print STDERR "$errmess\n";
    PublishCode('MESSAGE');
    exit;
}

1;

__END__

=back

=head1 SEE ALSO

  Labyrinth

=head1 AUTHOR

Barbie, <barbie@missbarbell.co.uk> for
Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2002-2011 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or
  modify it under the Artistic License 2.0.

=cut
