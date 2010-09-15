use Test::More;
use IO::File;
use Labyrinth;

# Skip if doing a regular install
plan skip_all => "Author tests not required for installation"
    unless ( $ENV{AUTOMATED_TESTING} );

my $changes;
$changes = 'Changes' if(-f 'Changes');
$changes = 'CHANGES' if(-f 'CHANGES');

plan skip_all => 'No Changes file found'    unless($changes);

my $fh = IO::File->new($changes,'r')   or plan skip_all => "Cannot open $changes file";

plan no_plan;

my $latest = 0;
while(<$fh>) {
    next        unless(m!^\d!);
    $latest = 1 if(m!^$Labyrinth::VERSION!);
    like($_, qr!\d[\d._]+\s+\d{2}/\d{2}/\d{4}!,'... version has a date');
}

is($latest,1,'... latest version not listed');
