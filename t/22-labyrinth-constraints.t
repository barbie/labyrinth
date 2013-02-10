#!/usr/bin/perl -w
use strict;

use Data::FormValidator;
use Test::More tests => 24;
use Labyrinth::Constraints;
use Labyrinth::Variables;

Labyrinth::Variables::init();   # initial standard variable values

my @examples = (
    [ undef,        0, undef        ],
    [ '',           0, undef        ],
    [ '12-12-2013', 1, '12-12-2013' ],
    [ '2013-02-08', 0, undef        ],
    [ '05022013',   0, undef        ],
);

for my $ex (@examples) {
    is(valid_ddmmyy(undef,$ex->[0]), $ex->[1],  "'" . (defined $ex->[0] ? $ex->[0] : 'undef') ."' validates as expected for ddmmyy"     );
    is(match_ddmmyy(undef,$ex->[0]), $ex->[2],  "'" . (defined $ex->[0] ? $ex->[0] : 'undef') ."' matches as expected for ddmmyy"       );
}

@examples = (
    [ undef,                0, undef                    ],
    [ '',                   0, undef                    ],
    [ 'http://test.com',    1, 'http://test.com'        ],
    [ 'http://',            0, undef                    ],
    [ 'xyz://test.com',     0, undef                    ],
    [ 'test.com',           1, 'http://test.com'        ],
    [ 'www.test.com',       1, 'http://www.test.com'    ],
);

for my $ex (@examples) {
    is(valid_url(undef,$ex->[0]), $ex->[1],  "'" . (defined $ex->[0] ? $ex->[0] : 'undef') ."' validates as expected for url"   );
    is(match_url(undef,$ex->[0]), $ex->[2],  "'" . (defined $ex->[0] ? $ex->[0] : 'undef') ."' matches as expected for url"     );
}
