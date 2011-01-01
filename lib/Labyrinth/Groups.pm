package Labyrinth::Groups;

use warnings;
use strict;

use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT @EXPORT_OK);
$VERSION = '5.01';

=head1 NAME

Labyrinth::Groups - handler for Labyrinth groups

=head1 DESCRIPTION

Contains all the groups handling functionality

=cut

# -------------------------------------
# Export Details

require Exporter;
@ISA = qw(Exporter);

%EXPORT_TAGS = (
    'all' => [ qw( GetGroupID UserInGroup GroupSelect GroupSelectMulti ) ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = ( @{ $EXPORT_TAGS{'all'} } );

# -------------------------------------
# Library Modules

use Labyrinth::Audit;
use Labyrinth::Globals  qw(:default);
use Labyrinth::DBUtils;
use Labyrinth::MLUtils;
use Labyrinth::Session;
use Labyrinth::Support;
use Labyrinth::Variables;

# -------------------------------------
# The Subs

=head1 FUNCTIONS

=over 4

=item GetGroupID

=item UserInGroup

=item GroupSelect

=item GroupSelectMulti

=cut

sub GetGroupID {
    my $name = shift;
    my @rows = $dbi->GetQuery('array','GetGroupID',$name);
    return undef    unless(@rows);
    return $rows[0]->[0];
}

my %InGroup;

sub UserInGroup {
    my $groupid = shift;
    my $userid  = shift || $tvars{loginid};
    return 0    unless($groupid && $userid);

    $InGroup{$userid} ||= do { UserGroups($userid) };
    return 1    if($InGroup{$userid} =~ /\b$groupid\b/);
    return 0;
}

sub GroupSelect {
    my $opt = shift;
    my @rows = $dbi->GetQuery('hash','AllGroups');
    unshift @rows, {groupid => 0, groupname => 'Select A Group' };
    return DropDownRows($opt,'groups','groupid','groupname',@rows);
}

sub GroupSelectMulti {
    my $opt   = shift;
    my $multi = shift || 5;
    my @rows = $dbi->GetQuery('hash','AllGroups');
    unshift @rows, {groupid => 0, groupname => 'Select A Group' };
    return DropDownMultiRows($opt,'groups','groupid','groupname',$multi,@rows);
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
