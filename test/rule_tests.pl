#!/usr/bin/perl

# cpanm Test::Assert
use Test::Assert ':all';
use FindBin;
use lib "$FindBin::Bin/..";
use AdjustLibris;
use Data::Dumper;
use List::Compare;

test_all();

sub test_all {
    test_all_rule_041();
    test_all_rule_020();
    test_all_rule_030();
    test_all_rule_035();
    test_all_rule_082();
}

# Test rules applying to 041
sub test_all_rule_041 {
    test_rule_041();
}

sub test_rule_041 {
    my $record_without_041 =
        AdjustLibris::open_record("test/data/rule_041-without_041.mrc");
    my $record_with_041 =
        AdjustLibris::open_record("test/data/rule_041-with_041.mrc");
    my $record_wrong_lang =
        AdjustLibris::open_record("test/data/rule_041-wrong_lang.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_041($record_without_041);
    assert_equals("eng", $new_record->subfield("041", "a"),
                  "should add 041$a when it does not exist");
    
    $new_record = AdjustLibris::rule_041($record_with_041);
    my @new_fields = $new_record->field("041");
    my $new_count = @new_fields;
    my @old_fields = $record_with_041->field("041");
    my $old_count = @old_fields;
    assert_equals($old_count, $new_count,
                  "should not touch 041$a when it already exists (no fields should be added)");
    assert_equals($record_with_041->subfield("041", "a"), $new_record->subfield("041", "a"),
                  "should not touch 041$a when it already exists (existing field should remain)");
    
    $new_record = AdjustLibris::rule_041($record_wrong_lang);
    assert_null($new_record->subfield("041", "a"),
                "should not create 041$a if 008/35-37 is und, xxx or mul");
}

# Test rules applying to 020
sub test_all_rule_020 {
    test_rule_020();
}

sub test_rule_020 {
    my $record_020z_with_dash =
        AdjustLibris::open_record("test/data/rule_020-z_with_dash.mrc");
    my $record_020a_with_dash =
        AdjustLibris::open_record("test/data/rule_020-a_with_dash.mrc");

    my $new_record;

    my $record_020z_multiple = AdjustLibris::clone($record_020z_with_dash);
    $record_020z_multiple->delete_fields($record_020z_multiple->field('020'));
    $record_020z_multiple->append_fields(MARC::Field->new('020','','','a' => "123-345", 'z' => "123-999", 'h' => 'Lite-text', 'z' => "123-800"));
    
    $new_record = AdjustLibris::rule_020($record_020z_with_dash);
    assert_equals("9339344444444", $new_record->subfield("020", "z"), 
                  "should remove all dashes from 020\$z");

    $new_record = AdjustLibris::rule_020($record_020a_with_dash);
    assert_equals("9339344444444", $new_record->subfield("020", "a"), 
                  "should remove all dashes from 020\$a");

    $new_record = AdjustLibris::rule_020($record_020z_multiple);
    my @expected_zlist = ("123999", "123800");
    my @new_zlist = $new_record->subfield('020', 'z');
    assert_deep_equals(\@expected_zlist, \@new_zlist, 
                  "should remove all dashes from 020\$z");
}

# Test rules applying to 030
sub test_all_rule_030 {
    test_rule_030();
}

sub test_rule_030 {
    my $record_030 =
        AdjustLibris::open_record("test/data/rule_030.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_030($record_030);

    my @fields = $new_record->field('030');
    my $field_count = @fields;
    assert_equals(5, $field_count, "should deduplicate 030 based on $a (field count)");
    assert_equals("CODEN1", $fields[0]->subfield('a'),
                  "should deduplicate 030 based on $a (field 0)");
    assert_null($fields[0]->subfield('z'),
                "should deduplicate 030 based on $a (field 0)");
    assert_equals("CODENINVAL", $fields[1]->subfield('z'),
                  "should deduplicate 030 based on $a (field 1)");
    assert_null($fields[1]->subfield('a'),
                "should deduplicate 030 based on $a (field 1)");
    assert_equals("CODENINVAL2", $fields[2]->subfield('z'),
                  "should deduplicate 030 based on $a (field 2)");
    assert_null($fields[2]->subfield('a'),
                "should deduplicate 030 based on $a (field 2)");
    assert_equals("CODEN2", $fields[3]->subfield('a'),
                  "should deduplicate 030 based on $a (field 3)");
    assert_equals("CODENINVAL", $fields[3]->subfield('z'),
                  "should deduplicate 030 based on $a (field 3)");
    assert_equals("CODEN3", $fields[4]->subfield('a'),
                  "should deduplicate 030 based on $a (field 4)");
    assert_equals("CODENINVAL", $fields[4]->subfield('z'),
                  "should deduplicate 030 based on $a (field 4)");
}

# Test rules applying to 035
sub test_all_rule_035 {
    test_rule_035_a_issn();
    test_rule_035_9_issn();
    test_rule_035_9_to_a();
    test_rule_035_5();
}

sub test_rule_035_a_issn {
    my $record_035_with_suba_8chars =
        AdjustLibris::open_record("test/data/rule_035-with_suba_8chars.mrc");
    my $record_035_with_suba_not_8chars =
        AdjustLibris::open_record("test/data/rule_035-with_suba_not_8chars.mrc");

    my $new_record;

    $new_record = AdjustLibris::rule_035_a_issn($record_035_with_suba_8chars);
    assert_equals("1111-2345", $new_record->subfield("035", "a"), 
                  "should insert a dash in 035$a if length is exactly 8 (issn)");

    $new_record = AdjustLibris::rule_035_a_issn($record_035_with_suba_not_8chars);
    assert_equals("991234567", $new_record->subfield("035", "a"), 
                  "should not insert a dash in 035$a if length is other than 8 (issn)");
}

sub test_rule_035_9_issn {
    my $record_035_with_sub9_8chars =
        AdjustLibris::open_record("test/data/rule_035-with_sub9_8chars.mrc");
    my $record_035_with_sub9_not_8chars =
        AdjustLibris::open_record("test/data/rule_035-with_sub9_not_8chars.mrc");

    my $new_record;

    $new_record = AdjustLibris::rule_035_9_issn($record_035_with_sub9_8chars);
    assert_equals("1111-2345", $new_record->subfield("035", "9"), 
        "should insert a dash in 035$9 if length is exactly 8 (issn)");

    $new_record = AdjustLibris::rule_035_9_issn($record_035_with_sub9_not_8chars);
    assert_equals("991234567", $new_record->subfield("035", "9"), 
        "should not insert a dash in 035$9 if length is other than 8 (issn)");
}

sub test_rule_035_9_to_a {
    my $record_035_with_sub9_not_8chars =
        AdjustLibris::open_record("test/data/rule_035-with_sub9_not_8chars.mrc");

    my $new_record;

    $new_record = AdjustLibris::rule_035_9_to_a($record_035_with_sub9_not_8chars);
    assert_null($new_record->subfield("035", "9"), "should be null");
    assert_equals("991234567", $new_record->subfield("035", "a"), 
        "should move 035$9 to 035$a");
}

sub test_rule_035_5 {
    my $record_035_with_sub5 =
        AdjustLibris::open_record("test/data/rule_035-with_sub5.mrc");

    my $new_record;

    $new_record = AdjustLibris::rule_035_5($record_035_with_sub5);
    assert_null($new_record->field('035'), "should remove a 035 field if it has a $5");
}

# Test rules applying to 082
sub test_all_rule_082 {
    test_rule_082();
}

sub test_rule_082 {
    my $record_082 =
        AdjustLibris::open_record("test/data/rule_082.mrc");

    my $new_record;

    my @old_fields = $record_082->field("082");
    my $old_record_count = @old_fields;
    assert_equals(2, $old_record_count, "should deduplicate 082 (before dedup)");
    $new_record = AdjustLibris::rule_082($record_082);
    my @new_fields = $new_record->field("082");
    my $new_record_count = @new_fields;
    assert_equals(1, $new_record_count, "should deduplicate 082 (after dedup)");
}    

