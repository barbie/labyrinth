package Labyrinth::Writer;

use warnings;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '5.01';

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

=cut

# -------------------------------------
# Export Details

require Exporter;
@ISA       = qw( Exporter );
@EXPORT_OK = qw( Publish PublishCode UnPublish Transform Croak );
@EXPORT    = qw( Publish PublishCode UnPublish Transform Croak );

# -------------------------------------
# Library Modules

use CGI                 qw(:standard);
use Template;
use File::Basename;

use Labyrinth::Audit;
use Labyrinth::Globals;
use Labyrinth::Variables;
use Labyrinth::MLUtils;

# -------------------------------------
# Variables

my %codes = (
    BADLAYOUT       => 'public/badlayout.html',
    BADPAGE         => 'public/badpage.html',
    BADCMD          => 'public/badcommand.html',
    MESSAGE         => 'public/error_message.html',
);

my $published;

my %binary = (
    pdf             => 'application/pdf',
);

# -------------------------------------
# The Subs

=head1 FUNCTIONS

=over 4

=item Publish()

Publish() parses a given template, via Template Toolkit, and prints the
result.

=item PublishCode

=item UnPublish

=item Transform

=cut

sub Publish {
    return  if($published);

    my $path = $settings{'templates'};
    my $vars = \%tvars;

    if($vars->{redirect}) {
        print $cgi->redirect($vars->{redirect});
        return;
    }

    # binary files are output directly
    if($vars->{'contenttype'} && $binary{$vars->{'contenttype'}}) {
        #LogDebug("content-type=[$vars->{'contenttype'}]");
        #LogDebug("content-file=[$vars->{'file'}]");
        my $fh = IO::File->new($settings{webdir}.'/'.$vars->{'file'},'r');
        if($fh) {
            print $cgi->header( -type => $binary{$vars->{'contenttype'}} );
            my $buffer;
            while(read($fh,$buffer,1024)) { print $buffer }
            $fh->close;
            $published = 1;
            return;
        }
    }

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
    use Data::Dumper;
    LogDebug( "vars=".Dumper($vars) );


    my %config = (                              # provide config info
        RELATIVE        => 1,
        ABSOLUTE        => 1,
        INCLUDE_PATH    => $path,
        INTERPOLATE     => 0,
        POST_CHOMP      => 1,
        TRIM            => 1,
        EVAL_PERL       => ($content eq $codes{BADPAGE} ? 1 : 0),
    );

    my $contenttype = 'text/html';
    $contenttype = 'application/xml'    if($layout =~ /\.(rss|xml)$/);
    $contenttype = 'text/plain'         if($layout =~ /\.txt$/);
    $contenttype = 'text/calendar'      if($layout =~ /\.ics$/);

    my %cgihash = (
        -type=>$contenttype
    );
    $cgihash{'-status'}     = '404 Page Not Found'  if($content eq $codes{BADPAGE} || $content eq $codes{BADCMD});
    $cgihash{'-cookie'}     = $vars->{cookie}       if($vars->{cookie});
    $cgihash{'-attachment'} = basename($content)    if($layout =~ /\.ics$/);
    #LogDebug("CGI Hash=".Dumper(\%cgihash));
    print $cgi->header( %cgihash );

    #LogDebug("<!-- $layout : $content -->");

    my $parser = Template->new(\%config);   # initialise parser
    if($layout =~ /\.html$/) {
        my $html;
        eval { $parser->process($layout,$vars,\$html) };
        die $parser->error()    if($@);
        my ($top,$body,$tail) = ($html =~ m!^(.*?<body[^>]*>)(.*?)(</body>.*)$!si);
#   LogDebug( "html=[$html]" );
#   LogDebug( "top=[$top]" );
#   LogDebug( "tail=[$tail]" );
#   LogDebug( "body=[$body]" );
        print $top . process_html($body,0,1) . $tail;
    } else {
        $parser->process($layout,$vars)         # parse the template
            or die $parser->error();
    }

    $published = 1;
}

sub PublishCode {
    $tvars{'content'} = $codes{$_[0]};
#   LogDebug("code=$_[0]");
#   LogDebug("content=$codes{$_[0]}");
    Publish();
}

sub UnPublish {
    $published = 0;
}

sub Transform {
    my ($template,$vars,$output) = @_;

    #print STDERR "Transform: template=$template, output=$output\n";
    #LogDebug("Transform: template=$template, output=$output");

    my $path = $settings{'templates'};
    my $layout = "$path/$template";

    #LogDebug("Transform: layout=$layout");

    die "Missing template [$layout]\n"  unless(-e $layout);

    my %config = (                              # provide config info
        RELATIVE        => 1,
        ABSOLUTE        => 1,
        INCLUDE_PATH    => $path,
        OUTPUT_PATH     => $vars->{cache},
        INTERPOLATE     => 0,
        POST_CHOMP      => 1,
        TRIM            => 1,
    );

    my $parser = Template->new(\%config);   # initialise parser
    #eval {
    $parser->process($layout,$vars,$output) # parse the template
        or die $parser->error();
    #};
    #if($@) {
    #    my $error = $parser->error();
    #    LogDebug("Transform: Error - $@");
    #    LogDebug("Transform: Type  - ".$error->type());
    #    LogDebug("Transform: Info  - ".$error->info());
    #}
    #LogDebug("Transform: Done");
}

=item Croak

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

  CGI,
  Template (Template Toolkit)
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
