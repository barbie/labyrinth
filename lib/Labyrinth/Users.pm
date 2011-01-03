package Labyrinth::Users;

use warnings;
use strict;

use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT @EXPORT_OK);
$VERSION = '5.02';

=head1 NAME

Labyrinth::Users - Generic User functions for Labyrinth

=head1 DESCRIPTION

Contains generic user functionality

=cut

# -------------------------------------
# Export Details

require Exporter;
@ISA = qw(Exporter);

%EXPORT_TAGS = (
    'all' => [ qw( UserName UserID FreshPassword PasswordCheck UserSelect ) ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = ( @{ $EXPORT_TAGS{'all'} } );

# -------------------------------------
# Library Modules

use Labyrinth::Audit;
use Labyrinth::Globals;
use Labyrinth::DBUtils;
use Labyrinth::MLUtils;
use Labyrinth::Variables;

use Crypt::RandPasswd;

# -------------------------------------
# Variables

my (%usernames,%userids);  # quick lookup hashes

# -------------------------------------
# The Subs

=head1 PUBLIC INTERFACE METHODS

=over 4

=item UserName($id)

=item UserID

=item FreshPassword

=item PasswordCheck

=back

=cut

sub UserName {
    my $uid = shift;
    return  unless($uid);

    $usernames{$uid} ||= do {
        my @rows = $dbi->GetQuery('hash','GetUserByID',$uid);
        $rows[0]->{realname} || $rows[0]->{nickname};
    };

    return $usernames{$uid};
}

sub UserID {
    my $name = shift;
    return  unless($name);

    $userids{$name} ||= do {
        my @rows = $dbi->GetQuery('hash','GetUserByName',$name);
        $rows[0]->{userid};
    };

    return $userids{$name};
}

sub FreshPassword {
    my $word;
    my $attempts;
    do {
        $word = Crypt::RandPasswd->chars(20,40);
        $word =~ s/[^-;,.:+=~\w]+//g;
        $attempts++;
    } until (length $word > 10 || $attempts > 10);
    return substr($word,0,10)   if(length($word) > 10);
    return 'Ch4ng3Th15';
}

sub PasswordCheck {
    my $password = shift;
    my $plen = length $password;

    return 4    if($password =~ /\s/);
    return 1    if($plen < $settings{minpasslen});
    return 2    if($plen > $settings{maxpasslen});

    # Check unique characters
    my @chars = split //,$password ;
    my %unique ;
    foreach my $char (@chars) {
        $unique{$char}++;
    }

    return 5    if(scalar keys %unique < 3);

    my $types = 0;
    $types++    if($password =~ /[a-z]/);
    $types++    if($password =~ /[A-Z]/);
    $types++    if($password =~ /\d/);
    $types++    if($password =~ /[^a-zA-Z\d]/);
    return 0    if($types > 1);

    return 3;
}

=head1 ADMIN INTERFACE METHODS

=over 4

=item UserSelect

=back

=cut

sub UserSelect {
    my $opt   = shift;
    my $multi = shift || 5;
    my $blank = shift || 0;
    my $title = shift || 'Name';
    my $all   = shift;

    my $search = 'WHERE search=1'   unless($all);

    my @rows = $dbi->GetQuery('hash','AllUsers',{search=>$search});
    foreach (@rows) { $_->{name} = $_->{realname} . ( $_->{nickname} ? ' (' . $_->{nickname} . ')' : '') }
    unshift @rows, {userid=>0,name=>"Select $title"}    if($blank == 1);
    return DropDownMultiRows($opt,'users','userid','name',$multi,@rows) if($multi > 1);
    return DropDownRows($opt,'userid','userid','name',@rows);
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