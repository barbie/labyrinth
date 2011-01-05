package Labyrinth::DIUtils::GDDriver;

use warnings;
use strict;

my $VERSION = '5.03';

=head1 NAME

Labyrinth::DIUtils::GDDriver - Digital Image utilities driver for GD.

=head1 SYNOPSIS

  use Labyrinth::DIUtils::GDDriver;

  my $hook = Labyrinth::DIUtils::GDDriver->new($file);
  my $hook = $hook->rotate($degrees);       # 0 - 360
  my $hook = $hook->reduce($xmax,$ymax);
  my $hook = $hook->thumb($thumbnail,$square);

=head1 DESCRIPTION

Handles the driver software for GD image manipulation; Do not use
this module directly, access via Labyrinth::DIUtils.

=cut

#############################################################################
#Modules/External Subroutines                                               #
#############################################################################

use GD;
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
    Croak("no image specified") if !$image;

    my $i = GD::Image->newFromJpeg($image) ;
    Croak("object image error: [$image]")   if !$i;

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

    my $p;
    $p = $i->copyRotate90()     if($degs == 90);
    $p = $i->copyRotate180()    if($degs == 180);
    $p = $i->copyRotate270()    if($degs == 270);
    _writeimage($self->{image},$p->jpeg);

    $self->{object} = $p;
}

=item reduce($xmax,$ymax)

Object Method. Passed a two arguments (defaulting to 100x100), which is then
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

    my ($w,$h);
    my ($width,$height) = $i->getBounds();
    return  unless($width > $xmax || $height > $ymax);

    my $x = ($xmax / $width);
    my $y = ($ymax / $height);

    if($x < $y) {
        $w = $xmax;
        $h = $height * $x;
    } else {
        $h = $ymax;
        $w = $width * $y;
    }

    my $p = GD::Image->new($w,$h);
    $p->copyResized($i,0,0,0,0,$w,$h,$width,$height);
    _writeimage($self->{image},$p->png);
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

    my ($w,$h);
    my ($width,$height) = $i->getBounds();
    if($width > $height) {
        $w = $smax;
        $h = ($height * $smax) / $width;
    } else {
        $h = $smax;
        $w = ($width * $smax) / $height;
    }

    my $p = GD::Image->new($w,$h);
    $p->copyResized($i,0,0,0,0,$w,$h,$width,$height);
    _writeimage($file,$p->png);
}

sub _writeimage {
    my ($file,$data) = @_;

    open    IMAGE, ">$file" || die "Cannot write to file [$file]: $!";
    binmode IMAGE;
    print   IMAGE $data;
    close   IMAGE;
}

1;

__END__

=head1 SEE ALSO

  GD
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
