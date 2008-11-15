#!perl
# Copyright (C) 2008, The Perl Foundation.
# $Id$

use strict;
use warnings;
use lib qw(t . lib ../lib ../../lib ../../../lib);

use Test::More;

use Parrot::Test tests => 3 * 9;
use Parrot::Test::Util 'create_tempfile';
use Parrot::Config;

=head1 NAME

pct/complete_workflow.t - PCT tests

=head1 SYNOPSIS

    $ prove t/compilers/pct/complete_workflow.t

=head1 DESCRIPTION

Special cases in grammars and actions should be tested here.

This test script builds a parser from a grammar syntax file.
After that acctions are added from a NQP class file.
After that the generated compiler is tested against a sample input.

=cut

{
    test_pct( 'sanity', <<'GRAMMAR', <<'ACTIONS', <<'OUT' );
token TOP   { 'thingy' {*} }
GRAMMAR

method TOP($/) {
    my $past  := PAST::Stmts.new(
                     PAST::Op.new(
                         PAST::Val.new(
                             :value( ~$/ ),
                             :returns('String')
                         ),
                         :pirop('say'),
                         :pasttype('pirop')
                     )
                 );

    make $past;
}
ACTIONS
thingy
OUT
}

{
    test_pct( 'key', <<'GRAMMAR', <<'ACTIONS', <<'OUT' );
token TOP   { 'thingy' {*}  #= key_for_thingy
            | 'stuff'  {*}  #= key_for_stuff  
            }
GRAMMAR

method TOP($/,$key) {
    my $past  := PAST::Stmts.new(
                     PAST::Op.new(
                         PAST::Val.new(
                             :value( ~$/ ~ " with key: '" ~ $key ~ "'" ),
                             :returns('String')
                         ),
                         :pirop('say'),
                         :pasttype('pirop')
                     )
                 );

    make $past;
}
ACTIONS
thingy with key: 'key_for_thingy'
OUT
}

{
    test_pct( 'our', <<'GRAMMAR', <<'ACTIONS', <<'OUT', todo => 'broken, our vars get lost' );
token TOP    { <thingy> {*} }
token thingy { 'thingy' {*} }
GRAMMAR

method TOP($/) {
    our $?MY_OUR_VAR := 'was passed down';
    make $( $<thingy> );
}

method thingy($/) {
    our $?MY_OUR_VAR;
    my $past  := PAST::Stmts.new(
                     PAST::Op.new(
                         PAST::Val.new(
                             :value( 'our var ' ~ $?MY_OUR_VAR ),
                             :returns('String')
                         ),
                         :pirop('say'),
                         :pasttype('pirop')
                     )
                 );

    make $past;
}
ACTIONS
our var was passed down
OUT
}

# 10 test cases in this sub
sub test_pct
{
    my ( $name, $grammar, $actions, $output, @other ) = @_;

    # Do not assume that . is in $PATH
    # places to look for things
    my $BUILD_DIR     = $PConfig{build_dir};
    my $TEST_DIR      = "$BUILD_DIR/t/compilers/pct";
    my $PARROT        = "$BUILD_DIR/parrot$PConfig{exe}";
    my $PGE_LIBRARY   = "$BUILD_DIR/runtime/parrot/library/PGE";
    my $PERL6GRAMMAR  = "$PGE_LIBRARY/Perl6Grammar.pbc";
    my $NQP           = "$BUILD_DIR/compilers/nqp/nqp.pbc";

    # this will be passed to pir_output_is()
    my $pir_code = <<'EOT';
.namespace [ 'TestGrammar'; 'Compiler' ]

.sub 'onload' :anon :load :init
    load_bytecode 'PCT.pbc'
.end

.sub 'main' :main

    .local pmc args
    args = new 'ResizableStringArray'
    push args, "test_program"
    push args, "t/compilers/pct/sample.txt"

    $P0 = new ['PCT'; 'HLLCompiler']
    $P0.'language'('TestGrammar')
    $P0.'parsegrammar'('TestGrammar::Grammar')
    $P0.'parseactions'('TestGrammar::Grammar::Actions')

    $P1 = $P0.'command_line'(args)

    .return()
.end

EOT

    # set up a file with the grammar
    my ($PG, $pg_fn) = create_tempfile( SUFFIX => '.pg', DIR => $TEST_DIR, UNLINK => 1 );
    print $PG <<"EOT";
# DO NOT EDIT.
# This file was generated by t/compilers/pct/complete_workflow.t

grammar TestGrammar::Grammar is PCT::Grammar;

$grammar

EOT

    ok( $pg_fn, "$name: got name of grammar file" );
    ok( -e $pg_fn, "$name: grammar file exists" );

    # compile the grammar
    # For easier debugging, the generated pir is appended to the PIR
    # that is passed to pir_output_is().
    ( my $gen_parser_fn = $pg_fn ) =~s/pg$/pir/;
    my $rv = Parrot::Test::run_command(
       qq{$PARROT $PERL6GRAMMAR $pg_fn},
       STDOUT => $gen_parser_fn,
       STDERR => $gen_parser_fn,
    );
    is( $rv, 0, "$name: generated PIR successfully" );
    ok( -e $gen_parser_fn, "$name: generated parser exist" );
    my $gen_parser = slurp_file($gen_parser_fn);
    unlink $gen_parser_fn;
    $pir_code .= <<"EOT";
#------------------------------#
# The generated parser         #
#------------------------------#

$gen_parser

EOT


    # set up a file with the actions
    my ($PM, $pm_fn) = create_tempfile( SUFFIX => '.pm', DIR => $TEST_DIR, UNLINK => 1 );
    print $PM <<"EOT";
# DO NOT EDIT.
# This file was generated by t/compilers/pct/complete_workflow.t

class TestGrammar::Grammar::Actions;

$actions

EOT

    ok( $pm_fn, "$name: got name of action file" );
    ok( -e $pm_fn, "$name: action file exists" );

    # compile the actions
    ( my $gen_actions_fn = $pm_fn ) =~s/nqp$/pir/;
    $rv = Parrot::Test::run_command(
       qq{$PARROT $NQP --target=pir $pm_fn},
       STDOUT => $gen_actions_fn,
       STDERR => $gen_actions_fn,
    );
    is( $rv, 0, "$name: generated PIR successfully" );
    ok( -e $gen_actions_fn, "$name: generated actions exist" );
    my $gen_actions = slurp_file($gen_actions_fn);
    unlink $gen_actions_fn;

    # Add the generated code to the driver,
    # so that everything is in one place
    $pir_code .= <<"EOT";

#------------------------------#
# The generated actions        #
#------------------------------#

$gen_actions

EOT

    pir_output_is( $pir_code, $output , "$name: output of compiler", @other );

    return;
}


=head1 AUTHOR

Bernhard Schmalhofer <Bernhard.Schmalhofer@gmx.de>

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
