package Labyrinth::DIUtils::IMDriver;

use warnings;
use strict;

my $VERSION = '5.02';

=head1 NAME

Labyrinth::DIUtils::IMDriver - Digital Image utilities driver for ImageMagick.

=head1 SYNOPSIS

  use Labyrinth::DIUtils::IMDriver;

  my $hook = Labyrinth::DIUtils::IMDriver->new($file);
  my $hook = $hook->rotate($degrees);       # 0 - 360
  my $hook = $hook->reduce($xmax,$ymax);
  my $hook = $hook->thumb($thumbnail,$square);

=head1 DESCRIPTION

Handles the driver software for ImageMagick image manipulation; Do not use
this module directly, access via Labyrinth::DIUtils.

=cut

#############################################################################
#Modules/External Subroutines                                               #
#############################################################################

use Image::Magick;
use Labyrinth::Writer;

#############################################################################
#Subroutines
#############################################################################

=head1 METHODS

=head2 Contructor

=over 4

=item new($file)

The constructor. Passed a single mandatory argument, which is then used as the
image file for all image manipulation.

=back

=cut

sub new {
    my $self = shift;
    my $image = shift;

    # read in current image
    my $i = Image::Magick->new();
    Croak("object image error: [$image]")   if !$i;
    my $c = $i->Read($image);
    Croak("read image error: [$image] $c")  if $c;

    my $atts = {
        'image'     => $image,
        'object'    => $i,
    };

    # create the object
    bless $atts, $self;
    return $atts;
}


=head2 Image Manipulation

=over 4

=item rotate($degrees)

Object Method. Passed a single mandatory argument, which is then used to turn
the image file the number of degrees specified.

=cut

sub rotate {
    my $self = shift;
    my $degs = shift || return undef;

    return  unless($self->{image});

    my $i = $self->{object};
    return  unless($i);

    $i->Rotate(degrees => $degs);
    my $c = $i->Write($self->{image});
    Croak("write image error: [$self->{image}] $c\n")   if $c;
}

=item reduce($xmax,$ymax)

Object Method. Passed two arguments (defaulting to 100x100), which is then
used to reduce the image to a size that fit inside a box of the specified
dimensions.

=cut

sub reduce {
    my $self = shift;
    my $xmax = shift || 100;
    my $ymax = shift || 100;

    return  unless($self->{image});

    my $i = $self->{object};
    return  unless($i);

    my ($width,$height) = $i->Get('columns', 'rows');
    return  unless($width > $xmax || $height > $ymax);

    $i->Scale(geometry => "${xmax}x${ymax}");
    my $c = $i->Write($self->{image});
    Croak("write image error: [$self->{image}] $c\n")   if $c;
}

=item thumb($thumbnail,$square)

Object Method. Passed two arguments, the first being the name of the thumbnail
file to be created, and the second being a single dimension of the square box
(defaulting to 100), which is then used to reduce the image to a thumbnail.

=back

=cut

sub thumb {
    my $self = shift;
    my $file = shift;
    my $smax = shift || 100;

    my $i = $self->{object};
    return  unless($i);

    $i->Scale(geometry => "${smax}x${smax}");
    my $c = $i->Write($file);
    Croak("write image error: [$file] $c\n")    if $c;
}

1;

__END__

=head1 SEE ALSO

  Image::Magick
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
