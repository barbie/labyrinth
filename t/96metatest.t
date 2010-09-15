use Test::More;

# Skip if doing a regular install
plan skip_all => "Author tests not required for installation"
    unless ( $ENV{AUTOMATED_TESTING} );

eval "use Test::JSON::Meta 0.08";
plan skip_all => "Test::JSON::Meta 0.08 required for testing META.json files" if $@;

plan no_plan;

my $meta = meta_spec_ok(undef,undef,@_);

use Labyrinth;
my $version = $Labyrinth::VERSION;

is($meta->{version},$version,
    'META.json distribution version matches');

if($meta->{provides}) {
    for my $mod (keys %{$meta->{provides}}) {
        is($meta->{provides}{$mod}{version},$version,
            "META.json entry [$mod] version matches");
    }
}
