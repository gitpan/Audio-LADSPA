#!/usr/bin/perl -w

use Test::More tests => 4;

use strict;
BEGIN {
    $|++;
    use_ok('Graph::Directed');
}

package Dummy;

sub new {
    my ($class) = @_;
    return bless {},$class;
}

sub test {
    return unless ref($_[0]);
    return unless $_[0]->isa("Dummy");
    return 1;
}

package main;

my $G =  Graph::Directed->new();
ok ($G->isa("Graph::Directed"),"Graph instance");

my $d1 = Dummy->new;
my $d2 = Dummy->new;
$G->add_edge($d1,$d2);
$G->set_attribute('object',$d1,$d1);
$G->set_attribute('object',$d2,$d2);

my @d = eval {
    grep { $G->get_attribute('object',$_)->test } $G->toposort();
}; 
ok (!$@,"Objects as attributes");
ok( @d == 2,"Objects as attributes2");


