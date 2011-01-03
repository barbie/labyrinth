package Labyrinth::Constraints::Emails;

use warnings;
use strict;

use vars qw($VERSION $AUTOLOAD);
$VERSION = '5.02';

=head1 NAME

Labyrinth::Constraints::Emails - Data constraints for email

=head1 DESCRIPTION

=cut

#----------------------------------------------------------------------------
# Exporter Settings

require Exporter;
use vars qw($VERSION @ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(
    emails      valid_emails        match_emails
    email_rfc   valid_email_rfc     match_email_rfc
);

#----------------------------------------------------------------------------
# Variables

# RFC 2396, base definitions.
my $digit           =  '[0-9]';
my $alpha           =  '[a-zA-Z]';                # lowalpha | upalpha
my $alphanum        =  '[a-zA-Z0-9]';             # alpha    | digit

my $IPv4address     =  "(?:$digit+[.]$digit+[.]$digit+[.]$digit+)";
my $toplabel        =  "(?:$alpha"."[-a-zA-Z0-9]*$alphanum|$alpha)";
my $domainlabel     =  "(?:(?:$alphanum"."[-a-zA-Z0-9]*)?$alphanum)";
my $hostname        =  "(?:(?:$domainlabel\[.])*$toplabel\[.]?)";
my $host            =  "(?:$hostname|$IPv4address)";

# RFC 2822, base definitions.
my $atom_strict     = qr¬[\w!\#\$\%\&\'\*\+\-\/=\?^\`{|}~]¬i;
my $local_strict    = qr¬$alphanum(?:\.?$atom_strict)*¬;
my $local_quoted    = qr¬\"$local_strict(?:\ $local_strict)*\"¬;
my $email_strict    = qr¬$local_strict\@$host¬;

my $atom_harsh      = qr¬[\w\'\+\-=]¬i;
my $local_harsh     = qr¬$alphanum(?:\.?$atom_harsh)*¬;
my $email_harsh     = qr¬$local_harsh\@$host¬;

#----------------------------------------------------------------------------
# Subroutines

=head1 FUNCTIONS

=head2 emails

=over 4

=item emails

=item valid_emails

=item match_emails

=back

=cut

sub emails {
    my %params = @_;
    return sub {
        my $self = shift;
        $self->set_current_constraint_name('emails');
        $self->valid_emails($self,\%params);
    }
}

sub match_emails {
    my ($self,$text) = @_;
    $text =~ m< ^($email_harsh )$ >x ? $1 : undef;
}

=head2 email_rfc

=over 4

=item email_rfc

=item valid_email_rfc

=item match_email_rfc

=back

=cut

sub email_rfc {
    my %params = @_;
    return sub {
        my $self = shift;
        $self->set_current_constraint_name('email_rfc');
        $self->valid_email_rfc(\%params);
    }
}

sub match_email_rfc {
    my ($self,$text) = @_;
    $text =~ m< ^( $email_strict )$ >x ? $1 : undef;
}

sub AUTOLOAD {
    my $name = $AUTOLOAD;

    no strict qw/refs/;

    $name =~ m/^(.*::)(valid_|RE_)(.*)/;

    my ($pkg,$prefix,$sub) = ($1,$2,$3);

    # Since all the valid_* routines are essentially identical we're
    # going to generate them dynamically from match_ routines with the same names.
    if ((defined $prefix) and ($prefix eq 'valid_')) {
        return defined &{$pkg.'match_' . $sub}(@_);
    }
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
