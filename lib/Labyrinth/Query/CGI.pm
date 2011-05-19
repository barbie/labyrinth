package Labyrinth::Query::CGI;

use warnings;
use strict;

my $VERSION = '5.06';

=head1 NAME

Labyrinth::Query::CGI - Environment hander for Labyrinth.

=head1 SYNOPSIS

  use Labyrinth::Query::CGI;
  my $cgi = Labyrinth::Query::CGI->new();

  $cgi->env();
  $cgi->Vars();
  $cgi->cookie();

=head1 DESCRIPTION

A thin wrapper around CGI.pm.

=cut

# -------------------------------------
# Library Modules

use base qw(CGI);
use CGI::Cookie;

# -------------------------------------
# The Subs

=head1 METHODS

=over 4

=item new

Object constructor.

=item env

Provides the %ENV hash.

=cut

sub new {
    my($class) = @_;
    CGI::initialize_globals();

    my $self = bless {
        env         => \%ENV,
    }, $class;

    $self->SUPER::init;

    $self;
}

sub env {
    my $self = shift;
    return $self->{env};
}

1;

__END__

=back

=head1 SEE ALSO

  CGI,
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
