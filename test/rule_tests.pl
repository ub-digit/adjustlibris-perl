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
    test_all_rule_084();
    test_all_rule_130();
    test_all_rule_222();
    test_all_rule_599();
    test_all_rule_440();
    test_all_rule_830();
    test_all_rule_clean_keyword_fields();
    test_all_rule_remove_hyphens_except_issn();
    test_all_rule_clean_holding_fields();
    test_all_rule_976();
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

# Test rules applying to 084
sub test_all_rule_084 {
    test_rule_084_5_2();
    test_rule_084_kssb();
    test_rule_084_5_not2();
    test_rule_084_to_089();
}

sub test_rule_084_5_2 {
    my $record_084_without_sub5_2 =
        AdjustLibris::open_record("test/data/rule_084-without_sub5_2.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_084_5_2($record_084_without_sub5_2);
    assert_null($new_record->field('084'), "should remove field if no $5 or $2 is present");
}

sub test_rule_084_kssb {
    my $record_084_with_multiple_kssb =
        AdjustLibris::open_record("test/data/rule_084-with_multiple_kssb.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_084_kssb($record_084_with_multiple_kssb);

    my @fields = $new_record->field('084');
    my $field_count = @fields;
    assert_equals(3, $field_count,
                  "should deduplicate 084 based on $a when $2 starts with kssb (field count)");
    assert_equals("F:do", $fields[0]->subfield('a'),
                  "should deduplicate 084 based on $a when $2 starts with kssb (field 0)");
    assert_equals("kssb/8 (machine generated)", $fields[0]->subfield('2'),
                  "should deduplicate 084 based on $a when $2 starts with kssb (field 0)");
    assert_equals("F:fno", $fields[1]->subfield('a'),
                  "should deduplicate 084 based on $a when $2 starts with kssb (field 1)");
    assert_equals("kssb/9", $fields[1]->subfield('2'),
                  "should deduplicate 084 based on $a when $2 starts with kssb (field 1)");
    assert_equals("F:other", $fields[2]->subfield('a'),
                  "should deduplicate 084 based on $a when $2 starts with kssb (field 2)");
    assert_equals("not same", $fields[2]->subfield('2'),
                  "should deduplicate 084 based on $a when $2 starts with kssb (field 2)");
}

sub test_rule_084_5_not2 {
    my $record_084_with_sub5_not2 =
        AdjustLibris::open_record("test/data/rule_084-with_sub5_not2.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_084_5_not2($record_084_with_sub5_not2);
    my @fields = $new_record->field('084');
    my $field_count = @fields;
    assert_equals(2, $field_count,
                  "should remove field if $5 is present, but not $2 except if $5 contains Ge (field count)");
    assert_equals("F:do", $fields[0]->subfield('a'),
                  "should remove field if $5 is present, but not $2 except if $5 contains Ge (field 0)");
    assert_null($fields[0]->subfield('5'),
                "should remove field if $5 is present, but not $2 except if $5 contains Ge (field 0)");
    assert_equals("F:other", $fields[1]->subfield('a'),
                  "should remove field if $5 is present, but not $2 except if $5 contains Ge (field 1)");
    assert_equals("Ge", $fields[1]->subfield('5'),
                  "should remove field if $5 is present, but not $2 except if $5 contains Ge (field 1)");
}

sub test_rule_084_to_089 {
    my $record_084_with_sub5_not2_to_089 =
        AdjustLibris::open_record("test/data/rule_084-with_sub5_not2_to_089.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_084_to_089($record_084_with_sub5_not2_to_089);
    my @fields = $new_record->field('084');
    my $field_count = @fields;
    assert_equals(1, $field_count,
                  "should convert field to 089 if $2 is not present or if $2 does not start with kssb (field count 084)");
    assert_equals("F:do", $fields[0]->subfield('a'),
                  "should convert field to 089 if $2 is not present or if $2 does not start with kssb (field 084)");
    assert_null($fields[0]->subfield('5'),
                "should convert field to 089 if $2 is not present or if $2 does not start with kssb (field 084)");
    
    @fields = $new_record->field('089');
    $field_count = @fields;
    assert_equals(1, $field_count,
                  "should convert field to 089 if $2 is not present or if $2 does not start with kssb (field count 089)");
    assert_equals("F:other", $fields[0]->subfield('a'),
                  "should convert field to 089 if $2 is not present or if $2 does not start with kssb (field 089)");
    assert_equals("Ge", $fields[0]->subfield('5'),
                  "should convert field to 089 if $2 is not present or if $2 does not start with kssb (field 089)");
}


# Test rules applying to 130
sub test_all_rule_130 {
    test_rule_130();
}

sub test_rule_130 {
    my $record_130_s =
        AdjustLibris::open_record("test/data/rule_130-leader_s.mrc");
    my $record_130_not_s =
        AdjustLibris::open_record("test/data/rule_130-leader_not_s.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_130($record_130_s);
    assert_null($new_record->field('130'), "should convert to 222 if LEADER7 is s");
    assert_equals("Title with - in its name", $new_record->subfield('222', 'a'), "should convert to 222 if LEADER7 is s");

    $new_record = AdjustLibris::rule_130($record_130_not_s);
    assert_null($new_record->field('222'), "should convert to 222 if LEADER7 is s");
    assert_equals("Title with - in its name", $new_record->subfield('130', 'a'), "should convert to 222 if LEADER7 is s");
}

# Test rules applying to 222
sub test_all_rule_222 {
    test_rule_222();
}

sub test_rule_222 {
    my $record_222 =
        AdjustLibris::open_record("test/data/rule_222.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_222($record_222);
    assert_equals("Title with / in its name", $new_record->subfield('222', 'a'),
                  "should replace _-_ with _/_ if present in $a");
}

# Test rules applying to 599
sub test_all_rule_599 {
    test_rule_599_ind1();
    test_rule_599_remove();
}

sub test_rule_599_ind1 {
    my $record_599_s =
        AdjustLibris::open_record("test/data/rule_599-s.mrc");
    my $record_599_not_s =
        AdjustLibris::open_record("test/data/rule_599-not_s.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_599_ind1($record_599_s);
    my @fields = $new_record->field('599');
    assert_equals("1", $fields[0]->indicator(1),
                  "should change ind1 to 1 if ind1 and ind2 are blank and LEADER7 is s (ind1)");
    assert_equals(" ", $fields[0]->indicator(2),
                  "should change ind1 to 1 if ind1 and ind2 are blank and LEADER7 is s (ind2)");

    $new_record = AdjustLibris::rule_599_ind1($record_599_not_s);
    @fields = $new_record->field('599');
    assert_equals(" ", $fields[0]->indicator(1),
                  "should not change ind1 if LEADER7 is other than s (ind1)");
    assert_equals(" ", $fields[0]->indicator(2),
                  "should not change ind1 if LEADER7 is other than s (ind2)");
}

sub test_rule_599_remove {
    my $record_599_not_s =
        AdjustLibris::open_record("test/data/rule_599-not_s.mrc");
    my $record_599_not_blank =
        AdjustLibris::open_record("test/data/rule_599-not_blank.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_599_remove($record_599_not_s);
    my @fields = $new_record->field('599');
    my $field_count = @fields;
    assert_equals(0, $field_count,
                  "should remove 599 where ind1 and ind2 are both blank (removed)");

    $new_record = AdjustLibris::rule_599_remove($record_599_not_blank);
    @fields = $new_record->field('599');
    $field_count = @fields;
    assert_equals(1, $field_count,
                  "should remove 599 where ind1 and ind2 are both blank (not removed)");
}


# Test rules applying to 440
sub test_all_rule_440 {
    test_rule_440();
}

sub test_rule_440 {
    my $record_440 =
        AdjustLibris::open_record("test/data/rule_440.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_440($record_440);
    assert_equals("Title with / in its name", $new_record->subfield('440', 'a'),
                  "should replace _-_ with _/_ if present in \$a");
}


# Test rules applying to 830
sub test_all_rule_830 {
    test_rule_830();
}

sub test_rule_830 {
    my $record_830 =
        AdjustLibris::open_record("test/data/rule_830.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_830($record_830);
    assert_equals("Title with / in its name", $new_record->subfield('830', 'a'),
                  "should replace _-_ with _/_ if present in \$a");
}

# Test rules applying to 648, 650, 651, 655
sub test_all_rule_clean_keyword_fields {
    test_rule_clean_keyword_fields();
}

sub test_rule_clean_keyword_fields {
    my $record_with_ind2_0 =
        AdjustLibris::open_record("test/data/rule_650-ind2_7fast_with_ind2_0.mrc");
    my $record_without_ind2_0 =
        AdjustLibris::open_record("test/data/rule_650-ind2_7fast_without_ind2_0.mrc");
    my $record_mesh_and_lc_no_dup =
        AdjustLibris::open_record("test/data/rule_650-ind2_2_and_ind2_0_no_dup.mrc");
    my $record_mesh_without_lc =
        AdjustLibris::open_record("test/data/rule_650-ind2_2_without_ind2_0.mrc");
    my $record_mesh_and_lc_with_dup =
        AdjustLibris::open_record("test/data/rule_650-ind2_2_and_ind2_0_with_dup.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_clean_keyword_fields($record_with_ind2_0, "650");
    my @fields = $new_record->field('650');
    my @fast_fields = ();
    foreach my $field (@fields) {
        if ($field->indicator(2) eq "7" && $field->subfield('2') eq "fast") {
            push(@fast_fields, $field);
        }
    }
    my $fast_field_count = @fast_fields;
    assert_equals(0, $fast_field_count,
                  "should remove 650 fields with ind2 == 7 and $2 == fast when any field with ind2 == 0 exists");

    $new_record = AdjustLibris::rule_clean_keyword_fields($record_without_ind2_0, "650");
    @fields = $new_record->field('650');
    @fast_fields = ();
    foreach my $field (@fields) {
        if ($field->indicator(2) eq "7" && $field->subfield('2') eq "fast") {
            push(@fast_fields, $field);
        }
    }
    $fast_field_count = @fast_fields;
    assert_equals(3, $fast_field_count,
                  "should not remove 650 fields with ind2 == 7 and $2 == fast when there are no ind2 == 0 fields");

    $new_record = AdjustLibris::rule_clean_keyword_fields($record_mesh_without_lc, "650");
    @fields = $new_record->field('650');
    @mesh_fields = ();
    foreach my $field (@fields) {
        if ($field->indicator(2) eq "2") {
            push(@mesh_fields, $field);
        }
    }
    $mesh_field_count = @mesh_fields;
    assert_equals(3, $mesh_field_count,
                  "should keep all ind2 == 2 when as is when no ind2 == 0 exists");

    $new_record = AdjustLibris::rule_clean_keyword_fields($record_mesh_and_lc_no_dup, "650");
    @fields = $new_record->field('650');
    @mesh_fields = ();
    foreach my $field (@fields) {
        if ($field->indicator(2) eq "2") {
            push(@mesh_fields, $field);
        }
    }
    $mesh_field_count = @mesh_fields;
    @lc_fields = ();
    foreach my $field (@fields) {
        if ($field->indicator(2) eq "0") {
            push(@lc_fields, $field);
        }
    }
    my $lc_field_count = @lc_fields;
    assert_equals(3, $mesh_field_count,
                  "should keep all ind2 == 2 and ind2 == 0 when they do not overlap (mesh)");
    assert_equals(3, $lc_field_count,
                  "should keep all ind2 == 2 and ind2 == 0 when they do not overlap (lc)");

    $new_record = AdjustLibris::rule_clean_keyword_fields($record_mesh_and_lc_with_dup, "650");
    @fields = $new_record->field('650');
    @mesh_fields = ();
    foreach my $field (@fields) {
        if ($field->indicator(2) eq "2") {
            push(@mesh_fields, $field);
        }
    }
    $mesh_field_count = @mesh_fields;
    @lc_fields = ();
    foreach my $field (@fields) {
        if ($field->indicator(2) eq "0") {
            push(@lc_fields, $field);
        }
    }
    $lc_field_count = @lc_fields;
    assert_equals(3, $mesh_field_count,
                  "should keep ind2 == 2 and ind2 == 0 but only ind2 == 2 when duplicate with ind2 == 0 (mesh)");
    assert_equals(1, $lc_field_count,
                  "should keep ind2 == 2 and ind2 == 0 but only ind2 == 2 when duplicate with ind2 == 0 (lc)");
}

# Test rules applying to 760, 762, 765, 767, 770, 772, 776, 779, 780, 785, 787
sub test_all_rule_remove_hyphens_except_issn {
    test_rule_remove_hyphens_except_issn();
}

sub test_rule_remove_hyphens_except_issn {
    my $record_760 =
        AdjustLibris::open_record("test/data/rule_760.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_remove_hyphens_except_issn($record_760, "760");
    my @fields = $new_record->field('760');
    assert_equals('1234-567X', $fields[0]->subfield('w'),
                  "should not remove hyphens in FIELD$w FIELD$x and FIELD$z if it matches an ISSN (####-####) (field0 w)");
    assert_equals('1111-1234', $fields[1]->subfield('x'),
                  "should not remove hyphens in FIELD$w FIELD$x and FIELD$z if it matches an ISSN (####-####) (field1 x)");
    assert_equals('13229222333', $fields[1]->subfield('w'),
                  "should remove hyphens in FIELD\$w FIELD\$x and FIELD\$z (field1 w)");
    assert_equals('13229222333', $fields[2]->subfield('x'),
                  "should remove hyphens in FIELD\$w FIELD\$x and FIELD\$z (field2 x)");
    assert_equals('1129233333', $fields[2]->subfield('z'),
                  "should remove hyphens in FIELD\$w FIELD\$x and FIELD\$z (field2 z)");
}


# Test rules applying to 852, 866
sub test_all_rule_clean_holding_fields {
    test_rule_clean_holding_fields();
}

sub test_rule_clean_holding_fields {
    my $record_old_with_c =
        AdjustLibris::open_record("test/data/rule_852_old_with_c.mrc");
    my $record_old_serial_with_c =
        AdjustLibris::open_record("test/data/rule_852_old_serial_with_c.mrc");
    my $record_old_without_c =
        AdjustLibris::open_record("test/data/rule_852_old_without_c.mrc");
    my $record_new_with_c =
        AdjustLibris::open_record("test/data/rule_852_new_with_c.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_clean_holding_fields($record_old_with_c, "852");
    my @fields = $new_record->field('852');
    my $field_count = @fields;
    assert_equals(3, $field_count,
                  "should clean 852 without \\c when any 852 contains \\c for old (1970-2001) books");
    
    $new_record = AdjustLibris::rule_clean_holding_fields($record_old_without_c, "852");
    @fields = $new_record->field('852');
    $field_count = @fields;
    assert_equals(4, $field_count,
                  "should not clean 852 when no 852 contains \\c");
    
    $new_record = AdjustLibris::rule_clean_holding_fields($record_new_with_c, "852");
    @fields = $new_record->field('852');
    $field_count = @fields;
    assert_equals(4, $field_count,
                  "should not clean 852 if record is newer than 2001");
    
    $new_record = AdjustLibris::rule_clean_holding_fields($record_old_serial_with_c, "852");
    @fields = $new_record->field('852');
    $field_count = @fields;
    assert_equals(4, $field_count,
                  "should not clean 852 if record other than monograph");
}


# Test rules applying to 976
sub test_all_rule_976 {
    test_rule_976();
}

sub test_rule_976 {
    my $record_976 =
        AdjustLibris::open_record("test/data/rule_976.mrc");

    my $new_record;
    $new_record = AdjustLibris::rule_976($record_976);
    assert_equals("Test Test Test", $new_record->subfield('976', 'a'),
                  "should remove 976$a and move \$b to \$a");
    assert_null($new_record->subfield('976', 'b'),
                "should remove 976$a and move \$b to \$a");
}

