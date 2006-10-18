#!perl
# Copyright (C) 2006, The Perl Foundation.
# $Id$

use strict;
use warnings;
use lib qw( . lib ../lib ../../lib );
use Test::More;
use Parrot::Test tests => 1;

=head1 NAME

t/pmc/sharedref.t - test the SharedRef PMC


=head1 SYNOPSIS

    % prove t/pmc/sharedref.t

=head1 DESCRIPTION

Tests the SharedRef PMC.

=cut


pir_output_is(<<'CODE', <<'OUT', 'new');
.sub 'test' :main
    new P0, .SharedRef
    print "ok 1\n"
.end
CODE
ok 1
OUT



# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
