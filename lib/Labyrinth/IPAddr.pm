package Labyrinth::IPAddr;

use warnings;
use strict;

use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT @EXPORT_OK);
$VERSION = '5.01';

=head1 NAME

Labyrinth::IPAddr - Set of general IP Address checking Functions.

=head1 SYNOPSIS

  use Labyrinth::IPAddr;

  CheckIP();
  BlockIP($who,$ipaddr);
  AllowIP($who,$ipaddr);

=head1 DESCRIPTION

The IPAddr package contains generic functions used for validating known IP
addresses. Used to allow known safe address to use the site without hindrance
and to refuse access to spammers.

=head1 EXPORT

  CheckIP
  BlockIP
  AllowIP

=cut

# -------------------------------------
# Constants

use constant BLOCK => 1;
use constant ALLOW => 2;

# -------------------------------------
# Export Details

require Exporter;
@ISA = qw(Exporter);
@EXPORT    = ( qw( CheckIP BlockIP AllowIP BLOCK ALLOW) );

# -------------------------------------
# Library Modules

use Labyrinth::Globals;
use Labyrinth::DBUtils;
use Labyrinth::Variables;

# -------------------------------------
# The Subs

=head1 FUNCTIONS

=over 4

=item CheckIP

Checks whether the current request sender IP address is know, and if so returns
the classification. Return codes are:

  0 - Unknown
  1 - Blocked
  2 - Allowed

=cut

sub CheckIP {
    my @rows = $dbi->GetQuery('hash','FindIPAddress',$settings{ipaddr});
    return @rows ? $rows[0]->{type} : 0;
}


=item BlockIP

Block current request sender IP address.

=cut

sub BlockIP {
    my $who     = shift || '';
    my $ipaddr  = shift || return;

    if(my @rows = $dbi->GetQuery('array','FindIPAddress',$ipaddr)) {
        $dbi->DoQuery('SaveIPAddress',$who,1,$ipaddr);
    } else {
        $dbi->DoQuery('AddIPAddress',$who,1,$ipaddr);
    }
}

=item AllowIP

Allow current request sender IP address.

=cut

sub AllowIP {
    my $who     = shift || '';
    my $ipaddr  = shift || return;

    if(my @rows = $dbi->GetQuery('array','FindIPAddress',$ipaddr)) {
        $dbi->DoQuery('SaveIPAddress',$who,2,$ipaddr);
    } else {
        $dbi->DoQuery('AddIPAddress',$who,2,$ipaddr);
    }
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
  modify it under the same terms as Perl itself.

=cut
