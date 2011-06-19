package Labyrinth::Media;

use warnings;
use strict;

use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT @EXPORT_OK);
$VERSION = '5.08';

=head1 NAME

Labyrinth::Media - Media files handler for Labyrinth

=head1 DESCRIPTION

This module collates many media and image file handling functionality used
within Labyrinth.

It should be noted that internally images and media files are stored in the
same, although images also record dimensions. When retrieving the required
files, it is recommend you call the appropriate method to ensure you are
getting the correct format of data for the file format. For example, GetImage
and GetMedia, both return file information, but GetImage adds deminsion data.

Also note that Images and Photos differ in the directory structure storage, so
saving and copying need to reference different functions. See below for a more
detailed explanation.

=cut

# -------------------------------------
# Export Details

require Exporter;
@ISA = qw(Exporter);

%EXPORT_TAGS = (
    'all' => [ qw(
                    CGIFile
                    StockSelect StockName StockPath StockType PathMove
                    GetImage SaveImageFile MirrorImageFile
                    CopyPhotoFile SavePhotoFile
                    GetMedia SaveMedia SaveFile UnZipFile
                    GetImageSize GetGravatar
                ) ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = ( @{ $EXPORT_TAGS{'all'} } );

# -------------------------------------
# Library Modules

use Archive::Extract;
use Digest::MD5 qw(md5_hex);
use File::Path;
use File::Copy;
use File::Basename;
use Image::Size;
use URI::Escape qw(uri_escape);
use WWW::Mechanize;

use Labyrinth::Audit;
use Labyrinth::Globals  qw(:default);
use Labyrinth::DBUtils;
use Labyrinth::DIUtils;
use Labyrinth::Metadata;
use Labyrinth::MLUtils;
use Labyrinth::Plugins;
use Labyrinth::Support;
use Labyrinth::Variables;

# -------------------------------------
# Constants

use constant    MaxDefaultWidth     => 120;
use constant    MaxDefaultHeight    => 120;
use constant    MaxDefaultThumb     => 120;

# -------------------------------------
# Variables

{ # START Stock Control

my @CHARS = (
    qw/A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
       a b c d e f g h i j k l m n o p q r s t u v w x y z
       0 1 2 3 4 5 6 7 8 9 _
      /);

my %stock;

# -------------------------------------
# The Functions

=head1 PUBLIC INTERFACE FUNCTIONS

=head2 Stock Control Functions

=over

=item CGIFile

When uploading a file via a web form, this function will save the file to the
local filesystem.

=back

=cut

sub CGIFile {
    my $param = shift;
    my $stock = shift || 1;

    my $f = $cgi->param($param) || die "Cannot access filehandle\n";

    _init_stock()   unless(%stock);
    $stock = 1  unless($stock{$stock});
    my $path = "$settings{webdir}/$stock{$stock}->{path}";
    mkpath($path);

    my ($name,$suffix) = ($f =~ m!([^/\\]*)(\.\w+)$!);
    my $filename;
    my $tries = 0;
    while(1) {
        last    if($tries++ > 10);
        $filename = "$path/" . _randname('imgXXXXXX') . lc($suffix);
        next    if(-f $filename);
        last;
    }

    die "Unable to create temporary file" if(-f $filename);
    my $fh = IO::File->new($filename, "w")    or die "Unable to create temporary file";
    binmode($fh);# if ($^O =~ /OS2|VMS|Win|DOS|Cygwin/i);

    my $buffer;
    while(read($f,$buffer,1024)) { print $fh $buffer }
    close($fh);

    $filename =~ s!^$settings{webdir}/!!;
    return ($name,$filename,$suffix);
}

=head2 Stock Control Functions

The stock list relates to the directory paths where uploaded files should be
saved on the local filesystem.

=over

=item StockName

Return the name for the given stock id.

=item StockPath

Return the path for the given stock id.

=item StockType

Return the stock id for the given stock code.

=item StockSelect

Returns an XHTML snippet for a dropdown selection box of stock entries.

=item PathMove

=back

=cut

sub StockName {
    my $stock = shift || 1;
    _init_stock()   unless(%stock);
    return $stock{$stock}->{title};
}

sub StockPath {
    my $stock = shift || 1;
    _init_stock()   unless(%stock);
    return $stock{$stock}->{path};
}

sub StockType {
    my $stock = shift || 'DRAFT';
    _init_stock()   unless(%stock);
    for(keys %stock) {
        return $_   if($stock{$_}->{title} eq $stock);
    }
    return 1;   # default
}

sub StockSelect {
    my $opt   = shift || 0;
    my $blank = shift || 1;
    _init_stock()   unless(%stock);

    my $html = "<select name='type'>";
    $html .= "<option value='0'>Select</option>"    if(defined $blank && $blank == 1);

    foreach (sort {$a <=> $b} keys %stock) {
        $html .= "<option value='$_'";
        $html .= ' selected="selected"' if($opt == $_);
        $html .= ">$stock{$_}->{title}</option>";
    }
    $html .= "</select>";

    return $html;
}

sub PathMove {
    my ($stockid,$link) = @_;
    my ($path,$name) = ($link =~ m!(.+)/([^/]+)!);
    return $link    if($stock{$stockid}->{path} eq $path);

    my $old = "$settings{webdir}/$link";
    my $new = "$settings{webdir}/$stock{$stockid}->{path}/$name";

    rename $old, $new;
    return "$stock{$stockid}->{path}/$name";
}

# -------------------------------------
# Private Functions

sub _init_stock {
    my @rows = $dbi->GetQuery('hash','AllImageStock');
    $stock{$_->{stockid}} = $_  for(@rows);
}

sub _randname {
    my $path = shift;
    $path =~ s/X(?=X*\z)/$CHARS[ int( rand( $#CHARS ) ) ]/ge;
    return $path;
}

} # END Stock Control

# -------------------------------------
# Public Image Functions

=head2 Image Functions

=over 4

=item GetImage($imageid)

Retrieves the image data for a given imageid.

=item SaveImageFile(%hash)

Saves an uploaded image file into the specified directory structure. If not
save directory is specified, the draft folder is used. The hash can contain
the following:

  param     - the CGI parameter used to reference the upload file
  width     - maximum saved width (default = 120px)
  height    - maximum saved height (default = 120px)
  imageid   - if overwriting already existing file
  stock     - file category (used to define the save directory)

=item MirrorImageFile

Mirrors a file from a URL to the local file system.

=item GetImageSize

For a given file, returns the true width and height that will be rendered
within the browser, given the current and default settings.

=item GetGravatar

Returns a Gravatar link.

=back

=cut

sub GetImage {
    my $imageid = shift;
    my @rows = $dbi->GetQuery('hash','GetImageByID',$imageid);
    return()    unless(@rows);

    my ($x,$y);
    if($rows[0]->{dimensions}) {
        ($x,$y) = split("x",$rows[0]->{dimensions});
    } else {
        ($x,$y) = imgsize($settings{webdir}.'/'.$rows[0]->{link});
    }
    return($rows[0]->{tag},$rows[0]->{link},$rows[0]->{href},$x,$y);
}


# stock type DRAFT should always be id 1
# DRAFT images are removed during reaping

sub MirrorImageFile {
    my ($source,$stock,$xmax,$ymax) = @_;
    my $stockid = StockType($stock);

    my $name = basename($source);
    my $file = StockPath($stockid) . '/' . $name;
    my $target = $settings{'webdir'} . '/' . $file;

    my $mechanize = WWW::Mechanize->new();
    $mechanize->mirror( $source, $target );

    my $i = Labyrinth::DIUtils->new($target);
    $i->reduce($xmax,$ymax);

    my ($size_x,$size_y) = imgsize($target);

    my $imageid = SaveImage(    undef,
                                $name,          # tag (maybe keywords)
                                $file,          # filename
                                $stockid,       # stock type
                                undef,
                                $size_x.'x'.$size_y);
    return ($imageid,$file);
}

sub SaveImageFile {
    my %hash = @_;

    my $param   = $hash{param};
    my $xmax    = $hash{width}  || MaxDefaultWidth;
    my $ymax    = $hash{height} || MaxDefaultHeight;
    my $imageid = $hash{imageid};
    my $stock   = StockType($hash{stock});

    return  unless($param && $cgiparams{$param});

    my ($name,$filename) = CGIFile($param,$stock);
    return 1    unless($name);  # blank if anything goes wrong

    my $i = Labyrinth::DIUtils->new("$settings{webdir}/$filename");
    $i->reduce($xmax,$ymax);

    my ($size_x,$size_y) = imgsize("$settings{webdir}/$filename");

    $imageid = SaveImage(   $imageid,
                            $name,          # tag (maybe keywords)
                            $filename,      # filename
                            $stock,         # stock type
                            $hash{href},
                            $size_x.'x'.$size_y);
    return ($imageid,$filename);
}

sub GetImageSize {
    my ($link,$size,$width,$height,$maxwidth,$maxheight) = @_;
    $maxwidth  ||= MaxDefaultWidth;
    $maxheight ||= MaxDefaultHeight;

    my ($w,$h) = $size ? split('x',$size) : (0,0);
    ($w,$h) = imgsize("$settings{webdir}/$link") unless($w || $h);

    ($width,$height) = ($w,$h)  unless($width || $height);

    # long winded to avoid uninitialised variable errors
    if(defined $width && defined $height && $width > $height && $width > $maxwidth) {
        $width  = $maxwidth;
        $height = 0;
    } elsif(defined $width && defined $height && $width < $height && $height > $maxheight) {
        $height = $maxheight;
        $width  = 0;
    } elsif(defined $width && $width > $maxwidth) {
        $width  = $maxwidth;
        $height = 0;
    } elsif(defined $height && $height > $maxheight) {
        $height = $maxheight;
        $width  = 0;
    }

    if($width && $height) {
        # nothing
    } elsif( $width && !$height) {
        $height = int($h * ($width  / $w));
    } elsif(!$width &&  $height) {
        $width  = int($w * ($height / $h));
    }

    #LogDebug("dimensions: x.($w,$h) / ($width,$height) / ($settings{webdir}/$link)");

    return ($width,$height);
}

sub GetGravatar {
    my ($id,$email) = @_;
    my $nophoto = uri_escape($settings{nophoto});

    return $nophoto     unless($id);
    my @rows = $dbi->GetQuery('hash','GetUserByID',$id);
    return $nophoto     unless(@rows);

    return
        'http://www.gravatar.com/avatar.php?'
        .'gravatar_id='.md5_hex($email)
        .'&amp;default='.$nophoto
        .'&amp;size=80';
}

=head2 Image Functions

=over 4

=item CopyPhotoFile()

Copy an existing stored image, both on the filesystem and in the database.

=item SavePhotoFile()

Save a photo uploaded via a web form to the local filesystem and to the photo
gallery database table.

=back

=cut

sub CopyPhotoFile {
    my %hash = @_;

    my $photo = $hash{photo};
    my $xmax  = $hash{width}  || MaxDefaultWidth;
    my $ymax  = $hash{height} || MaxDefaultHeight;
    my $stock = StockType($hash{stock});

    return  unless($photo);

    my @rs = $dbi->GetQuery('hash','GetPhotoDetail',$photo);
    my $name = basename($rs[0]->{image});
    return 1    unless($name);  # blank if anything goes wrong

    my $source = "$settings{webdir}/photos/$rs[0]->{image}";
    my $target = "$settings{webdir}/images/draft/$name";
    copy($source,$target);

    my $i = Labyrinth::DIUtils->new($target);
    $i->reduce($xmax,$ymax);

    my ($size_x,$size_y) = imgsize($target);

    $target =~ s!$settings{webdir}/!!;

    my $imageid = SaveImage(    undef,
                                $name,          # tag (maybe keywords)
                                $target,        # filename
                                $stock,         # stock type
                                $hash{href},
                                $size_x.'x'.$size_y);
    return ($imageid,$target);
}

sub SavePhotoFile {
    my %hash = @_;

    my $param = $hash{param}  || return;
    my $path  = $hash{path}   || return;
    my $page  = $hash{page}   || return;
    my $xmax  = $hash{width}  || MaxDefaultWidth;
    my $ymax  = $hash{height} || MaxDefaultHeight;
    my $smax  = $hash{thumb}  || MaxDefaultThumb;
    my $order = $hash{order}  || 1;
    my $tag   = $hash{tag};
    my $stock = StockType($hash{stock});

    return  unless($cgiparams{$param});

    my ($name,$filename,$extn) = CGIFile($param,$stock);
    return 1    unless($name);  # blank if anything goes wrong
    $tag = $name    unless(defined $tag);

    my $file = lc($name);
    $file =~ s/\s+//g;

    my $source = "$settings{webdir}/$filename";
    my $target = "$settings{webdir}/$path/$file$extn";
    copy($source,$target);

    $source = "$settings{webdir}/$path/$file$extn";
    $target = "$settings{webdir}/$path/$file-thumb$extn";
    copy($source,$target);

    my $i = Labyrinth::DIUtils->new($source);
    $i->reduce($xmax,$ymax);
    my $t = Labyrinth::DIUtils->new($target);
    $t->reduce($smax,$smax);

    my ($size_x,$size_y) = imgsize($source);

    $source =~ s!$settings{webdir}/(photos/)?!!;
    $target =~ s!$settings{webdir}/(photos/)?!!;
    my $photoid = $dbi->IDQuery('SavePhoto',$page,$target,$source,$size_x.'x'.$size_y,$tag,$order);

    MetaSave($photoid,['Photo'],split(/[ ,]+/,$name));

    return ($photoid,$name);
}

=head2 Media Functions

=over 4

=item GetMedia($imageid)

Retrieves the media data for a given imageid.

=item SaveMediaFile(%hash)

Saves an uploaded media file into the specified directory structure. If no
save directory is specified, the draft folder is used. The hash can contain
the following:

  param     - the CGI parameter used to reference the upload file
  imageid   - if overwriting already existing file
  stock     - file category (used to define the save directory)

=back

=cut

sub GetMedia {
    my $imageid = shift;
    my @rows = $dbi->GetQuery('hash','GetImageByID',$imageid);
    return()    unless(@rows);
    return($rows[0]->{tag},$rows[0]->{link},$rows[0]->{href});
}


# stock type DRAFT should always be id 1
# DRAFT images are removed during reaping

sub SaveMediaFile {
    my %hash = @_;

    my $param   = $hash{param};
    my $imageid = $hash{imageid};
    my $stock   = StockType($hash{stock});

    return  unless($param && $cgiparams{$param});

    my ($name,$filename) = CGIFile($param,$stock);
    return 1    unless($name);  # blank if anything goes wrong

    $imageid = SaveImage(   $imageid,
                            $name,          # tag (maybe keywords)
                            $filename,      # filename
                            $stock,         # stock type
                            $hash{href},
                            '');
    return ($imageid,$filename);
}

=over

=item SaveFile(%hash)

Saves an uploaded media file into the specified directory structure. If no
save directory is specified, the draft folder is used. The hash can contain
the following:

  param     - the CGI parameter used to reference the upload file
  stock     - file category (used to define the save directory)

Note that this upload function assumes that the file is to be stored in the
appropriate directory with a link being return. No imageid or further reference
is held within the database.

=back

=cut

sub SaveFile {
    my %hash = @_;

    my $param   = $hash{param};
    my $stock   = StockType($hash{stock});

    return  unless($param && $cgiparams{$param});

    my ($name,$filename) = CGIFile($param,$stock,1);
    return  unless($name);  # undef if anything goes wrong

    return $filename;
}

=head1 ADMIN INTERFACE FUNCTIONS

=over 4

=item ImageCheck

Used by Images::Delete to verify whether a particular module uses a particular
image referenced in the database.

=back

=cut

sub ImageCheck {
    my $imageid = shift;

    foreach my $plugin (get_plugins) {
        return 1    if( $plugin->ImageCheck($imageid) );
    }

    return 0;
}

=head1 LOCAL INTERNAL FUNCTIONS

=over 4

=item SaveImage

Writes image data to the database.

=cut

sub SaveImage {
    my ($imageid,@fields) = @_;

    if($imageid)    { $dbi->DoQuery('SaveImage',@fields,$imageid); }
    else            { $imageid = $dbi->IDQuery('AddImage',@fields); }

    return $imageid;
}

=item UnZipFile

Un wraps an archive file and stores it in an appropriate directory. For a
single file archive, the path to the file is returned. For collecions of
files, an 'index.html' is searched for and the path to it returned if
found. In all other instances the either the path to the first HTML file or
first other file is returned.

=cut

sub UnZipFile {
    my $file = shift;
    return  unless($file =~ /(.*)\.(zip|tar|tar\.gz|tgz)$/);

    my $path = $1;
    return  unless($path);

    # extract in to path directory
    # note ONLY ONE extraction allowed, in case zip of death uploaded

    my $ae = Archive::Extract->new( archive => "$settings{webdir}/$file" );
    my $ok = $ae->extract( to => "$settings{webdir}/$path" );
    unless($ok) {
        LogError("UnZip failure: file=[$file], path=[$path], error: ".$ae->error);
        rmtree("$settings{webdir}/$path");
        unlink("$settings{webdir}/$file");
        return;
    }

    my @files = map {s!$settings{webdir}/!!;$_} File::Find::Rule->file()->name('*')->in("$settings{webdir}/$path");
    unless(@files > 0) {
        LogError("UnZip failure: file=[$file], path=[$path], error: No files in archive.");
        rmtree("$settings{webdir}/$path");
        unlink("$settings{webdir}/$file");
        return;
    }

    # return file if count == 1
    return $files[0]    if(@files == 1);

    # return index.html if found
    my @html = grep {/^index.html?$/} @files;
    return $html[0]     if(@html);

    # return first html file if found
    @html = grep {/\.html?$/} @files;
    return $html[0]     if(@html);

    # return first file found
    return $files[0];
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
