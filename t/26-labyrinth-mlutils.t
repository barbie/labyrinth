#!/usr/bin/perl -w
use strict;

use Test::More  tests => 4;
use Labyrinth::MLUtils;
use Labyrinth::Variables;
use Data::Dumper;

Labyrinth::Variables::init();   # initial standard variable values

my @urls = (
    'http://technorati.com/faves?sub=addfavbtn&amp;add=http://blog.cpantesters.org',
    'http://static.technorati.com/pix/fave/tech-fav-1.png'
);


#diag($settings{urlregex});

    my $prot     = qr{(?:http|https|ftp|afs|news|nntp|mid|cid|mailto|wais|prospero|telnet|gopher|git)://};
    my $atom     = qr{[a-z\d]}i;
    my $domain   = qr{(?:(?:(?:$atom(?:(?:$atom|-)*$atom)?)\.)*(?:[a-zA-Z](?:(?:$atom|-)*$atom)?))};
    my $ip       = qr{(?:(?:\d+)(?:\.(?:\d+)){3})(?::(?:\d+))?};
    my $enc      = qr{%[a-fA-F\d]{2}};
    my $legal1   = qr{[a-zA-Z\d\$\-_.+!*\'(),~\#]};
    my $legal2   = qr{[\/;:@&=]};
    my $legal3   = qr{(?:(?:$legal1|$enc|$legal2)+)};
    my $path     = qr{\/$legal3};
    my $query    = qr{(?:\?$legal3)+};
    my $local    = qr{[-\w\'=.]+};

    my $urlregex = qr{(?: (?:$prot)?   (?:$domain|$ip|$path)  (?:(?:(?:$path)+)?  (?:$query)?  )?)  (?:\#[\w\-.]+)?}x;

for my $url (@urls) {
    is(Labyrinth::MLUtils::check_url_valid($url), 1, '.. valid url');
    like($url,qr/^$urlregex$/);
}
