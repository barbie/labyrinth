package Labyrinth::DTUtils;

use warnings;
use strict;

use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT @EXPORT_OK);
$VERSION = '5.20';

=head1 NAME

Labyrinth::DTUtils - Date & Time Utilities for Labyrinth

=head1 SYNOPSIS

  use Labyrinth::DTUtils;

=head1 DESCRIPTION

Various date & time utilities.

=head1 EXPORT

everything

=cut

# -------------------------------------
# Export Details

require Exporter;
@ISA = qw(Exporter);

%EXPORT_TAGS = (
    'all' => [ qw(
        DaySelect MonthSelect YearSelect PeriodSelect
        formatDate unformatDate isMonth
    ) ]
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
@EXPORT    = ( @{ $EXPORT_TAGS{'all'} } );

#############################################################################
#Libraries
#############################################################################

use Time::Local;
use Labyrinth::Audit;
use Labyrinth::MLUtils;
use Labyrinth::Variables;

#############################################################################
#Variables
#############################################################################

my @months = (
    { 'id' =>  1,   'value' => "January",   },
    { 'id' =>  2,   'value' => "February",  },
    { 'id' =>  3,   'value' => "March",     },
    { 'id' =>  4,   'value' => "April",     },
    { 'id' =>  5,   'value' => "May",       },
    { 'id' =>  6,   'value' => "June",      },
    { 'id' =>  7,   'value' => "July",      },
    { 'id' =>  8,   'value' => "August",    },
    { 'id' =>  9,   'value' => "September", },
    { 'id' => 10,   'value' => "October",   },
    { 'id' => 11,   'value' => "November",  },
    { 'id' => 12,   'value' => "December"   },
);

my @dotw = (    "Sunday", "Monday", "Tuesday", "Wednesday",
                "Thursday", "Friday", "Saturday" );

my @days = map {{'id'=>$_,'value'=> $_}} (1..31);
my @periods = (
    {act => 'evnt-month', value => 'Month'},
    {act => 'evnt-week',  value => 'Week'},
    {act => 'evnt-day',   value => 'Day'}
);

my %formats = (
    1 => 'YYYY',
    2 => 'MONTH YYYY',
    3 => 'DD/MM/YYYY',
    4 => 'DABV MABV DD TIME24 YYYY',
    5 => 'DAY, DD MONTH YYYY',
    6 => 'DAY, DDEXT MONTH YYYY',
    7 => 'DAY, DD MONTH YYYY (TIME12)',
    8 => 'DAY, DDEXT MONTH YYYY (TIME12)',
    9 => 'YYYY/MM/DD',
    10 => 'DDEXT MONTH YYYY',
    11 => 'YYYYMMDDThhmmss',        # iCal date string
    12 => 'YYYY-MM-DDThh:mm:ssZ',   # RSS date string
    13 => 'YYYYMMDD',               # backwards date
    14 => 'DABV, DDEXT MONTH YYYY',
    15 => 'DD MABV YYYY',
    16 => 'DABV, dd MABV YYYY hh:mm:ss TZ', # RFC-822 date string
    17 => 'DAY, DD MONTH YYYY hh:mm:ss',
    18 => 'DD/MM/YYYY hh:mm:ss',
    19 => 'DDEXT MONTH YYYY',
    20 => 'DABV, DD MABV YYYY hh:mm:ss',
    21 => 'YYYY-MM-DD hh:mm:ss',
);

# decrees whether the date format above should be UTC
# time based, or allow for any Summer Time variations.
my %zonetime = (12 => 1, 16 => 1);

#############################################################################
#Subroutines
#############################################################################

=head1 FUNCTIONS

=head2 Dropdown Boxes

=over 4

=item DaySelect

=item MonthSelect

=item YearSelect

=item PeriodSelect

=item OptSelect

=back

=cut

sub DaySelect {
    my ($opt,$blank) = @_;
    my @list = @days;
    unshift @list, {id=>0,value=>'Select Day'}  if(defined $blank && $blank == 1);
    DropDownRows($opt,'day','id','value',@list);
}

sub MonthSelect {
    my ($opt,$blank) = @_;
    my @list = @months;
    unshift @list, {id=>0,value=>'Select Month'}    if(defined $blank && $blank == 1);
    DropDownRows($opt,'month','id','value',@list);
}

# range:
# 0 - default
# 1 - given dates
# 2 - 1980 to now
# 3 - now to now+4

sub YearSelect {
    my ($opt,$range,$blank,$dates) = @_;
    my $year = formatDate(1);
    
    my $past_offset   = $settings{year_past_offset} || 0;
    my $future_offset = defined $settings{year_future_offset} ? $settings{year_future_offset} : 4;
    my $past   = $past_offset ? $year - $past_offset : $settings{year_past};
    my $future = $year + $future_offset;
    $past ||= $year;

    my @range = ($past .. $future);
    if(defined $range) {
        if($range == 1)     { @range = @$dates }
        elsif($range == 2)  { @range = ($past .. $year) }
        elsif($range == 3)  { @range = ($year .. $future) }
    }

    my @years = map {{'id'=>$_,'value'=> $_}} @range;
    unshift @years, {id=>0,value=>'Select Year'}    if(defined $blank && $blank == 1);
    DropDownRows($opt,'year','id','value',@years);
}

sub PeriodSelect {
    my ($opt,$blank) = @_;
    my @list = @periods;
    unshift @list, {id=>0,value=>'Select Period'}   if(defined $blank && $blank == 1);
    DropDownRows($opt,'period','act','value',@list);
}

sub OptSelect {
    my ($name,$opt,$list,$sort,$blank,$title) = @_;
    my $sorter = sub {0};

    if(!$sort)          { $sorter = sub {0} }
    elsif($sort == 1)   { $sorter = sub {$a <=> $b} }
    elsif($sort == 2)   { $sorter = sub {$a cmp $b} }

    my $html = "<select name='$name'>";
    $html .= "<option value='0'>Select $title</option>" if($blank);
    foreach my $item (sort $sorter keys %$list) {
        $html .= "<option value='$item'";
        $html .= ' selected="selected"' if($opt && $opt eq $item);
        $html .= ">$list->{$item}</option>";
    }
    $html .= "</select>";

    return $html;
}

## ------------------------------------
## Date Functions

=head2 Date Formatting

=over 4

=item formatDate

=item unformatDate

=item isMonth

=back

=cut

sub formatDate {
    my ($format,$time) = @_;
    my $now = $time ? 0 : 1;

    $time = time    unless($time);
    return $time    unless($format);

    my ($second,$minute,$hour,$day,$mon,$year,$dotw) = localtime($time);
    $year += 1900;

    if($now && $zonetime{$format}) {
        my $timezone = $settings{timezone} || 'Europe/London';
        my $dt = DateTime->new(
                    year => $year, month => $mon, day => $day,
                    hour => $hour, minute => $minute, second => $second,
                    time_zone => $timezone );
        $dt->set_time_zone('UTC');
        ($second,$minute,$hour,$day,$mon,$year) =
            ($dt->second,$dt->minute,$dt->hour,$dt->day,$dt->mon,$dt->year);
    }

    # create date mini strings
    my $fmonth  = sprintf "%s",   $months[$mon++]->{value};
    my $fsday   = sprintf "%d",   $day; # short form, ie 6
    my $fday    = sprintf "%02d", $day; # long form, ie 06
    my $fmon    = sprintf "%02d", $mon;
    my $fyear   = sprintf "%04d", $year;
    my $fdotw   = sprintf "%s",   (defined $dotw ? $dotw[$dotw] : '');
    my $fddext  = sprintf "%d%s", $day, _ext($day);
    my $amonth  = substr($fmonth,0,3);
    my $adotw   = substr($fdotw,0,3);
    my $time12  = sprintf "%d:%02d%s", ($hour>12?$hour%12:$hour), $minute, ($hour>11?'pm':'am');
    my $time24  = sprintf "%d:%02d:%02d", $hour, $minute, $second;
    my $fhour   = sprintf "%02d", $hour;
    my $fminute = sprintf "%02d", $minute;
    my $fsecond = sprintf "%02d", $second;

    my $fmt = $formats{$format};

    # transpose format string into a date string
    $fmt =~ s/hh/$fhour/;
    $fmt =~ s/mm/$fminute/;
    $fmt =~ s/ss/$fsecond/;
    $fmt =~ s/DMY/$fday-$fmon-$fyear/;
    $fmt =~ s/MDY/$fmon-$fday-$fyear/;
    $fmt =~ s/YMD/$fyear-$fmon-$fday/;
    $fmt =~ s/MABV/$amonth/;
    $fmt =~ s/DABV/$adotw/;
    $fmt =~ s/MONTH/$fmonth/;
    $fmt =~ s/DAY/$fdotw/;
    $fmt =~ s/DDEXT/$fddext/;
    $fmt =~ s/YYYY/$fyear/;
    $fmt =~ s/MM/$fmon/;
    $fmt =~ s/DD/$fday/;
    $fmt =~ s/dd/$fsday/;
    $fmt =~ s/TIME12/$time12/;
    $fmt =~ s/TIME24/$time24/;
    $fmt =~ s/TZ/UT/;

    return $fmt;
}

sub unformatDate {
    my ($format,$time) = @_;

    return time unless($format && $time);

    my @basic  = qw(ss mm hh DD MM YYYY);
    my %forms  = map {$_ => 0 } @basic, 'dd';

    my @fields = split(q![ ,/:-]+!,$formats{$format});
    my @values = split(q![ ,/:-]+!,$time);
    @forms{@fields} = @values;
    foreach (@basic) { $forms{$_} = int($forms{$_}) }

#use Data::Dumper;
#LogDebug("format=[$format], time=[$time]");
#LogDebug("fields=[@fields], values=[@values]");
#LogDebug("before=".Dumper(\%forms));

    ($forms{DD}) = $forms{dd} =~ /(\d+)/        if($forms{dd});
    ($forms{DD}) = $forms{DDEXT} =~ /(\d+)/     if($forms{DDEXT});
    $forms{MM} = isMonth($forms{MONTH})         if($forms{MONTH});
    $forms{MM} = isMonth($forms{MABV})          if($forms{MABV});
    ($forms{hh},$forms{mm},$forms{ss})  = ($forms{TIME24} =~ /(\d+)/g)              if($forms{TIME24});
    ($forms{hh},$forms{mm},$forms{APM}) = ($forms{TIME12} =~ /(\d+):(\d+)(am|pm)/)  if($forms{TIME12});
    $forms{hh}++    if($forms{APM} && $forms{APM} eq 'pm');
    $forms{MM}--    if($forms{MM}  && $forms{MM} > 0);

#LogDebug("after=".Dumper(\%forms));
    @values = map {$forms{$_}} @basic;
    return timelocal(@values);
}

sub _ext {
    my $day = shift;
    my $ext = "th";
    if($day == 1 || $day == 21 || $day == 31)   {   $ext = "st" }
    elsif($day == 2 || $day == 22)              {   $ext = "nd" }
    elsif($day == 3 || $day == 23)              {   $ext = "rd" }
    return $ext;
}

sub isMonth {
    my $month = shift;
    return (localtime)[4]+1 unless(defined $month && $month);

    foreach (@months) {
        return $_->{id} if($_->{value} =~ /$month/);
        return $_->{value} if($month eq $_->{id});
    }
    return 0;
}

1;

__END__

=head1 SEE ALSO

  Time::Local
  Labyrinth

=head1 AUTHOR

Barbie, <barbie@missbarbell.co.uk> for
Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2002-2014 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or
  modify it under the Artistic License 2.0.

=cut
