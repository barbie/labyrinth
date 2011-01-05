package Labyrinth::DIUtils;

use warnings;
use strict;

my $VERSION = '5.03';

=head1 NAME

Labyrinth::DIUtils - Digital Image utilities driver

=head1 SYNOPSIS

  use Labyrinth::DIUtils;

  Labyrinth::DIUtils::Tool('GD');           # switch to GD
  Labyrinth::DIUtils::Tool('IM');           # switch to ImageMagick (default)
  my $tool = Labyrinth::DIUtils::Tool;      # returns current tool setting

  my $hook = Labyrinth::DIUtils->new($file);
  my $hook = $hook->rotate($degrees);       # 0 - 360
  my $hook = $hook->reduce($xmax,$ymax);
  my $hook = $hook->thumb($thumbnail,$square);

=head1 DESCRIPTION

Handles the driver software for ImageMagick and GD image manipulation;

=cut

#############################################################################
#Modules/External Subroutines                                               #
#############################################################################

use Labyrinth::Globals;

#############################################################################
#Variables
#############################################################################

my $tool = 'IM';    # defaults to ImageMagick

#############################################################################
#Subroutines
#############################################################################

=head1 FUNCTIONS

=over 4

=item Tool

=back

=cut

sub Tool {
    @_ ? $tool = shift : $tool;
}

=head2 Contructor

=over 4

=item new()

=back

=cut

sub new {
    my $self = shift;
    my $file = shift;
    my $hook;

    if(!defined $file) {
        Croak("No image file specified to $self->new().");
    } elsif(!defined $tool) {
        Croak("No image tool specified for $self.");
    } elsif($tool eq 'IM') {
        require Labyrinth::DIUtils::IMDriver;
        $hook = Labyrinth::DIUtils::IMDriver->new($file);
    } elsif($tool eq 'GD') {
        require Labyrinth::DIUtils::GDDriver;
        $hook = Labyrinth::DIUtils::GDDriver->new($file);
    } else {
        Croak("Invalid image tool specified for $self.");
    }

    return $hook;   # a cheat, but does the job :)
}

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
