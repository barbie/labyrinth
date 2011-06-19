package Labyrinth::Groups;

use warnings;
use strict;

use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT @EXPORT_OK);
$VERSION = '5.08';

=head1 NAME

Labyrinth::Groups - Manage user groups in Labyrinth

=head1 DESCRIPTION

This package provides group management for user access. Groups can be used to
set permissions for a set of users, without setting individual user
permissions.

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

Returns the ID of the specific group.

=item UserInGroup

Checks whether the specified user (or current user) is in the specified group
Returns 1 if true, otherwise 0 for false.

=item GroupSelect([$opt])

Provides the XHTML code for a single select dropdown box. Pass the id of a
group to pre-select that group.

=item GroupSelectMulti([$opt[,$rows]])

Provides the XHTML code for a multiple select dropdown box. Pass the group id 
or an arrayref to a list of group ids to pre-select those groups. By default
the number of rows displayed is 5, although this can be changed by passing the
number of rows you require.

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
  modify it under the Artistic License 2.0.

=cut
