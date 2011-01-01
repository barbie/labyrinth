package Labyrinth::Support;

use warnings;
use strict;

use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT @EXPORT_OK);
$VERSION = '5.00';

=head1 NAME

Labyrinth::Support - library functionality for a specific installation.

=head1 SYNOPSIS

  use Labyrinth::Support;

=head1 DESCRIPTION

The functions contain herein are specific to the installation.

=head1 EXPORT

  Alignment
  AlignSelect

  PublishState
  PublishSelect
  PublishAction

  FieldCheck
  AuthorCheck
  AccessUser
  AccessGroup
  AccessSelect

  RealmCheck
  RealmSelect
  RealmName
  RealmID

  FolderName
  FolderSelect
  AreaSelect

=cut

# -------------------------------------
# Export Details

require Exporter;
@ISA = qw(Exporter);

%EXPORT_TAGS = (
    'all' => [ qw(
        Alignment AlignSelect
        PublishState PublishSelect PublishAction
        FieldCheck AuthorCheck AccessUser AccessGroup AccessSelect
        AccessAllFolders AccessAllAreas
        RealmCheck RealmSelect RealmName RealmID
        FolderName FolderSelect AreaSelect
    ) ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = ( @{ $EXPORT_TAGS{'all'} } );

# -------------------------------------
# Library Modules

use Time::Local;

use Labyrinth::Audit;
use Labyrinth::Globals;
use Labyrinth::Groups;
use Labyrinth::MLUtils;
use Labyrinth::Session;
use Labyrinth::Writer;
use Labyrinth::Variables;

# -------------------------------------
# The Subs

=head1 FUNCTIONS

=over 4

=item PublishState

=item PublishSelect

=item PublishAction

=cut

my %publishstates = (
    1 => {Action => 'Draft',    State => 'Draft' },
    2 => {Action => 'Submit',   State => 'Submitted' },
    3 => {Action => 'Publish',  State => 'Published' },
    4 => {Action => 'Archive',  State => 'Archived' },
);
my @states = map {{'id'=>$_,'value'=> $publishstates{$_}->{State}}} sort keys %publishstates;

sub PublishState {
    my $state = shift;
    return ''   unless($state);
    return $publishstates{$state}->{State};
}


sub PublishSelect {
    my ($opt,$blank) = @_;
    my @list = @states;
    unshift @list, {id=>0,value=>'Select Status'}   if(defined $blank && $blank == 1);
    DropDownRows($opt,'publish','id','value',@list);
}

sub PublishAction {
    my $opt = shift ||  1;
    my $ack = shift || -1;

    my $html = "<select name='publish'>";
    foreach (sort keys %publishstates) {
        unless($ack == -1) {
            next    if(!$ack && $_ != $opt);
            next    if($_ < $opt || $_ > $opt+1);
        }
        $html .= "<option value='$_'";
        $html .= ' selected="selected"' if($opt == $_);
        $html .= ">$publishstates{$_}->{Action}</option>";
    }

    $html .= "</select>";
    return $html;
}

my %alignments = (
    0 => 'none',
    1 => 'left',
    2 => 'centre',
    3 => 'right',
    4 => 'wrap',
);
my @alignments = map {{'id'=>$_,'value'=> $alignments{$_}}} sort keys %alignments;

=item Alignment

Returns the HTML block alignment selected.

=item AlignSelect

Returns the HTML for alignment selection dropdown list.

=cut

sub Alignment {
    my $opt = shift || 1;
    return $alignments{$opt};
}

sub AlignSelect {
    my $opt = shift || 0;
    my $num = shift || 0;
    DropDownRows($opt,"ALIGN$num",'id','value',@alignments);
}

=item AuthorCheck

Checks whether the current user is the author of the data requested, or has
permissions to allow them to access the data. If not sets the BADACCESS error
code, otherwise retrieves the data.

=cut

sub AuthorCheck {
    my ($key,$id,$permission) = @_;
    return 1    unless($cgiparams{$id});    # if the id key doesn't exist, this is likely to be a new entry

    if(defined $cgiparams{$id}) {
        return 1    unless($cgiparams{$id});
        $permission = ADMIN unless(defined $permission);

        my @rows = $dbi->GetQuery('hash',$key,$cgiparams{$id});
        $tvars{data}->{$_} = $rows[0]->{$_} for(keys %{$rows[0]});

        return 1    if(Authorised($permission));
        return 1    if($rows[0]->{userid} && $rows[0]->{userid} == $tvars{'loginid'});
    }

    $tvars{errcode} = 'BADACCESS';
    return 0;
}

=item FieldCheck(\@allfields,\@mandatory)

Stores all the input data listed in @allfields, then checks that all the fields
listed in @mandatory are provided. Any errors found during parameter parsing
both for missing mandatory fields and via Data::FormValidator are then flagged
and the error code set.

=cut

sub FieldCheck {
    my ($allfields,$mandatory) = @_;

    # store base list for re-edit page
    foreach (@$allfields) {
        # automatically turn arrays into strings, in case someone is trying
        # to subvert the data input process. known arrays are correctly stored
        # appropriately elsewhere.
        $tvars{data}->{$_} = join("|",CGIArray($_));
    }

    # check for mandatory fields
    my $errors = 0;
    foreach (@$mandatory) {
        if(defined $cgiparams{$_} && exists $cgiparams{$_} && $cgiparams{$_}) {
            # nothing
        } else {
            LogDebug("FieldCheck: mandatory missing - [$_]");
            $tvars{data}->{$_.'_err'} = ErrorSymbol();
            $errors++;
            $tvars{errcode} = 'ERROR';
        }
    }

    # check for invalid fields
    for my $z (keys %cgiparams) {
        next    unless($z =~ /err_(.*)/);
        my $x = $1;
        $tvars{data}->{$x . '_err'} = ErrorSymbol();
        $errors++;
        $tvars{errcode} = 'ERROR';
    }

    return($errors);
}

=item AccessUser

=item AccessGroup

=item AccessSelect

=item AccessAllAreas

=item AccessAllFolders

=item AcessAllAreas

=cut

sub AccessUser  {
    my $permission = shift;
    $permission = ADMIN unless(defined $permission);

    return 1    if(Authorised($permission));

    $tvars{errcode} = 'BADACCESS';
    return 0;
}

sub AccessGroup {
    my %hash = @_;
    my $groupid = $hash{ID} || GetGroupID($hash{NAME});
    return 0    unless($groupid);   # this not bad access, the group may have been deleted

    return 1    if UserInGroup($groupid);

    $tvars{errcode} = 'BADACCESS';
    return 0;
}

sub AccessSelect {
    my $opt  = shift || 0;
    my $name = shift || 'accessid';
    my $max  = Authorised(MASTER) ? MASTER : ADMIN;
    my @rows = $dbi->GetQuery('hash','AllAccess',$max);
    DropDownRows($opt,$name,'accessid','accessname',@rows);
}

sub AccessAllFolders {
    my $userid = shift || $tvars{loginid};
    my $access = shift || PUBLISHER;
    my $groups = getusergroups($userid);
    my @rows = $dbi->GetQuery('array','GetFolderAccess',
                        {groups=>$groups,userid=>$userid,access=>$access});
    my @folders = map {$_->[0]} @rows;
    return join(',',@folders);
}
sub AcessAllAreas {
    my @rows = $dbi->GetQuery('array','AllAreas');
    my @areas = map {"'$_->[0]'"} @rows;
    return join(',',@areas);
}

=item RealmCheck

=item RealmSelect

=item RealmName

=item RealmID

=cut

sub RealmCheck {
    while(@_) {
        my $realm = shift;
        return 1    if($realm eq $tvars{realm});
    }

    $tvars{errcode} = 'BADACCESS';
    return 0;   # failed
}

sub RealmSelect {
    my $opt = shift;
    my @rows = $dbi->GetQuery('hash','AllRealms');
    DropDownRows($opt,'realmid','realmid','name',@rows);
}

sub RealmName {
    my $id = shift;
    my @rows = $dbi->GetQuery('hash','GetRealmByID',$id);
    return $rows[0]->{realm};
}

sub RealmID {
    my $name = shift;
    my @rows = $dbi->GetQuery('hash','GetRealmByName',$name);
    return $rows[0]->{realmid};
}

=item FolderName

=item FolderSelect

=cut

sub FolderName {
    my $opt  = shift || return;
    my @rows = $dbi->GetQuery('hash','GetFolder',$opt);
    return @rows ? $rows[0]->{foldername} : undef;
}

sub FolderSelect {
    my $opt  = shift || 0;
    my $name = shift || 'accessid';
    my @rows = $dbi->GetQuery('hash','AllFolders');
    DropDownRows($opt,'folderid','folderid','foldername',@rows);
}

=item AreaSelect

=cut

sub AreaSelect {
    my $opt = shift;
    my @rows = $dbi->GetQuery('hash','AllAreas');
    DropDownRows($opt,'area','areaid','title',@rows);
}

1;

__END__

=back

=head1 SEE ALSO

  Time::Local
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
