#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/";
use AdjustLibris;

AdjustLibris::adjust_file("test/data/rule_035-with_sub9_8chars.mrc", "testfilout.mrc");

