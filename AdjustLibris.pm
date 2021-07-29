package AdjustLibris;

use MARC::Batch;
use MARC::Record;
use Data::Dumper;

use open qw( :std :encoding(UTF-8) );
binmode(STDOUT, ":encoding(UTF-8)");

sub clone {
    my ($record) = @_;

    return MARC::Record->new_from_usmarc($record->as_usmarc());
}

sub apply {
    my ($record) = @_;

    $record = rule_041($record);
    $record = rule_020($record);
    $record = rule_030($record);
    $record = rule_035_9_issn($record);
    $record = rule_035_a_issn($record);
    $record = rule_035_9_to_a($record);
    $record = rule_035_5($record);
    $record = rule_082($record);
    $record = rule_084_5_2($record);
    $record = rule_084_kssb($record);
    $record = rule_084_5_not2($record);
    $record = rule_084_to_089($record);
    $record = rule_130($record);
    $record = rule_222($record);
    $record = rule_599_ind1($record);
    $record = rule_599_remove($record);
    $record = rule_440($record);
    $record = rule_830($record);
    # Rules for 650, 648, 651, 655
    $record = rule_remove_hyphens_except_issn($record, "440");
    $record = rule_remove_hyphens_except_issn($record, "760");
    $record = rule_remove_hyphens_except_issn($record, "762");
    $record = rule_remove_hyphens_except_issn($record, "765");
    $record = rule_remove_hyphens_except_issn($record, "767");
    $record = rule_remove_hyphens_except_issn($record, "770");
    $record = rule_remove_hyphens_except_issn($record, "772");
    $record = rule_remove_hyphens_except_issn($record, "776");
    $record = rule_remove_hyphens_except_issn($record, "779");
    $record = rule_remove_hyphens_except_issn($record, "780");
    $record = rule_remove_hyphens_except_issn($record, "785");
    $record = rule_remove_hyphens_except_issn($record, "787");
    # Rules for 852, 866
    
    return $record;
}

sub rule_xxx {
    my ($record) = @_;
    $record = clone($record);

    
    
    return $record;
}



# If 041 does not exist, copy 008/35-37 to 041$a,
#   unless 008/35-37 is ["und", "xxx", "mul"]
sub rule_041 {
    my ($record) = @_;
    $record = clone($record);

    my $f008 = $record->field('008');
    if (!$f008) {
        die "ControlField 008 missing";
    }
    my $lang = substr($f008->data(), 35, 3);
    if (!(grep { $_ eq $lang } ("und", "xxx", "mul"))) {
        if(!$record->field('041')) {
            my $field = MARC::Field->new('041','','','a' => $lang);
            $record->append_fields($field);
        }
    }
    
    return $record;
}


# Remove any '-' from any 020$a and 020$z
sub rule_020 {
    my ($record) = @_;
    $record = clone($record);

    foreach my $f020 ($record->field('020')) {
        my @all_subfields = $f020->subfields();
        $f020->delete_subfield(match => qr/.*/);
        foreach my $subf (@all_subfields) {
            if($subf->[0] eq "a" || $subf->[0] eq "z") {
                $subf->[1] =~ s/-//g;
            }
            $f020->add_subfields($subf->[0] => $subf->[1]);
        }
    }
    
    return $record;
}


# Deduplicate 030 on $a
sub rule_030 {
    my ($record) = @_;
    $record = clone($record);

    my @found_fields = ();
    my @fields_to_remove = ();

    foreach $f030 ($record->field('030')) {
        if ($f030->subfield('a')) {
            if (exists_in_arrayref($f030->as_string('a', '^^!!^^'), \@found_fields)) {
                push(@fields_to_remove, $f030);
            } else {
                push(@found_fields, $f030->as_string('a', '^^!!^^'));
            }
        }
    }

    $record->delete_fields(@fields_to_remove);
    
    return $record;
}


# If 035$a contains exactly 8 characters, insert a dash in the middle.
sub rule_035_a_issn {
    my ($record) = @_;
    $record = clone($record);

    foreach $f035 ($record->field('035')) {
        $subfield = $f035->subfield('a');
        if ($subfield) {
            if(length($subfield) == 8) {
                $subfield =~ s/(....)(....)/$1-$2/;
                $f035->update('a' => $subfield);
            }
        }
    }
    
    return $record;
}

# If 035$9 contains exactly 8 characters, insert a dash in the middle.
sub rule_035_9_issn {
    my ($record) = @_;
    $record = clone($record);

    foreach $f035 ($record->field('035')) {
        $subfield = $f035->subfield('9');
        if ($subfield) {
            if(length($subfield) == 8) {
                $subfield =~ s/(....)(....)/$1-$2/;
                $f035->update('9' => $subfield);
            }
        }
    }
    
    return $record;
}

# If 035$9 exists, move it to 035$a.
sub rule_035_9_to_a {
    my ($record) = @_;
    $record = clone($record);

    foreach $f035 ($record->field('035')) {
        $subfield = $f035->subfield('9');
        if ($subfield) {
            $f035->add_subfields('a' => $subfield);
            $f035->delete_subfield(code => '9');
        }
    }
    
    return $record;
}

# If 035$5 exists, remove the entire 035 field.
sub rule_035_5 {
    my ($record) = @_;
    $record = clone($record);

    foreach $f035 ($record->field('035')) {
        if($f035->subfield('5')) {
            $record->delete_field($f035);
        }
    }
    
    return $record;
}


# Deduplicate 082 on exact match
sub rule_082 {
    my ($record) = @_;
    $record = clone($record);

    my @found_fields = ();
    my @fields_to_remove = ();

    foreach $f082 ($record->field('082')) {
        if (exists_in_arrayref($f082->as_formatted(), \@found_fields)) {
            push(@fields_to_remove, $f082);
        } else {
            push(@found_fields, $f082->as_formatted());
        }
    }

    $record->delete_fields(@fields_to_remove);
    
    return $record;
}

# Remove all 084 where neither $5 nor $2 exists.
sub rule_084_5_2 {
    my ($record) = @_;
    $record = clone($record);

    foreach $f084 ($record->field('084')) {
        if (!$f084->subfield('5') && !$f084->subfield('2')) {
            $record->delete_field($f084);
        }
    }
    
    return $record;
}

# Deduplicate 084 on $a when $2 starts with kssb. Keep highest kssb version.
sub rule_084_kssb {
    my ($record) = @_;
    $record = clone($record);

    my @found_fields = ();
    my @fields_to_remove = ();
    my %highest_kssb_for_a = ();

    foreach $f084 ($record->field('084')) {
        if ($f084->subfield('a') && $f084->subfield('2') =~ /^kssb/) {
            if (exists_in_arrayref($f084->as_string('a', '^^!!^^'), \@found_fields)) {
                my $kssb_value = $f084->subfield('2');
                $kssb_value =~ s/^kssb\/(\d+).*/$1/;
                if ($kssb_value <= $highest_kssb_for_a{$f084->subfield('a')}->{kssb}) {
                    push(@fields_to_remove, $f084);
                } else {
                    push(@fields_to_remove, $highest_kssb_for_a{$f084->subfield('a')}->{field});
                    $highest_kssb_for_a{$f084->subfield('a')} = {field => $f084, kssb => $kssb_value};
                }
            } else {
                push(@found_fields, $f084->as_string('a', '^^!!^^'));
                my $kssb_value = $f084->subfield('2');
                $kssb_value =~ s/^kssb\/(\d+).*/$1/;
                $highest_kssb_for_a{$f084->subfield('a')} = {field => $f084, kssb => $kssb_value};
            }
        }
    }

    $record->delete_fields(@fields_to_remove);
    
    return $record;
}

# 084 with $5 and not $2, remove unless $5 contains Ge
sub rule_084_5_not2 {
    my ($record) = @_;
    $record = clone($record);

    foreach $f084 ($record->field('084')) {
        if ($f084->subfield('5') && !$f084->subfield('2')) {
            if ($f084->subfield('5') ne "Ge") {
                $record->delete_field($f084);
            }
        }
    }
    
    return $record;
}

# 084 without $2 or where $2 does not start with kssb, convert to 089
sub rule_084_to_089 {
    my ($record) = @_;
    $record = clone($record);

    foreach $f084 ($record->field('084')) {
        if (!$f084->subfield('2') || $f084->subfield('2') !~ /^kssb/) {
            my $f089 = $f084->clone();
            $f089->set_tag('089');
            $record->append_fields($f089);
            $record->delete_field($f084);
        }
    }
    
    return $record;
}

# If LEADER7 is s and 130 exists, convert it to 222
sub rule_130 {
    my ($record) = @_;
    $record = clone($record);
    my $leader = $record->leader();
    my $type = substr($leader, 7, 1);
    my $f130 = $record->field('130');
    if ($f130 && $type eq "s") {
        my $f222 = $f130->clone();
        $f222->set_tag('222');
        $record->append_fields($f222);
        $record->delete_field($f130);
    }
    
    return $record;
}

# If 222$a contains ' - ', replace it with ' / '
sub rule_222 {
    my ($record) = @_;
    $record = clone($record);
    $record = replace_dashed_separator($record, "222", "a");
    return $record;
}


# If 599 ind1 and ind2 are blank, and LEADER is s, set ind1 to 1
sub rule_599_ind1 {
    my ($record) = @_;
    $record = clone($record);
    my $leader = $record->leader();
    my $type = substr($leader, 7, 1);

    if ($type eq "s") {
        foreach my $f599 ($record->field('599')) {
            if ($f599->indicator(1) eq " " && $f599->indicator(2) eq " ") {
                $f599->set_indicator(1, "1");
            }
        }
    }
    
    return $record;
}

# If 599 ind1 and ind2 are blank, remove the field
sub rule_599_remove {
    my ($record) = @_;
    $record = clone($record);

    foreach my $f599 ($record->field('599')) {
        if ($f599->indicator(1) eq " " && $f599->indicator(2) eq " ") {
            $record->delete_field($f599);
        }
    }
    
    return $record;
}

# If 440$a contains ' - ', replace it with ' / '
sub rule_440 {
    my ($record) = @_;
    $record = clone($record);
    $record = replace_dashed_separator($record, "440", "a");
    return $record;
}


# If 830$a contains ' - ', replace it with ' / '
sub rule_830 {
    my ($record) = @_;
    $record = clone($record);
    $record = replace_dashed_separator($record, "830", "a");
    return $record;
}

# Remove hyphens in FIELD$w FIELD$x and FIELD$z if it does not match ISSN
sub rule_remove_hyphens_except_issn {
    my ($record, $tag) = @_;
    $record = clone($record);
    $record = remove_hyphens_except_issn($record, $tag, ["w", "x", "z"]);
    return $record;
}


sub writer {
    my ($filename) = @_;

    open my $writer, ">$filename" || die "Error (writer): $! for $filename";

    return $writer;
}

sub reader {
    my ($filename) = @_;

    # don't let MARC::Batch open the file, as it applies the ':utf8' IO layer
    my $fh = IO::File->new($filename) || die "Error (reader): $! for $filename"; 
    my $reader = MARC::Batch->new('USMARC', $fh);
    $reader->warnings_off();
    $reader->strict_off();
    return $reader;
}

sub open_file {
    my ($input_filename) = @_;
    return reader($input_filename);
}

sub open_record {
    my ($input_filename) = @_;
    return open_file($input_filename)->next();
}

sub adjust_file {
    my ($input_filename, $output_filename) = @_;

    my $reader = reader($input_filename);
    my $writer = writer($output_filename);
  RECORD:
    while() {
        my $record;
        eval { $record = $reader->next() };
        if ($@) {
            print "Bad MARC record: $@ skipped\n";
            next;
        }

        if ($record) {
            my $newrecord = apply($record);
            print $writer $newrecord->as_usmarc();
        } else {
            last;
        }
    }
}

sub exists_in_arrayref {
    my ($needle, $haystack) = @_;
    
    foreach my $haystack_item (@{$haystack}) {
        if ($needle eq $haystack_item) {
            return 1;
        }
    }
    return 0;
}

# Replace ' - ' with ' / ' in specified field and subfield
sub replace_dashed_separator {
    my ($record, $tag, $subfield_code) = @_;
    my @fields = $record->field($tag);
    foreach $field (@fields) {
        my @all_subfields = $field->subfields();
        $field->delete_subfield(match => qr/.*/);
        foreach my $subf (@all_subfields) {
            if($subf->[0] eq $subfield_code) {
                $subf->[1] =~ s/ - / \/ /g;
            }
            $field->add_subfields($subf->[0] => $subf->[1]);
        }
    }
    return $record;
}

# Remove hyphens in record subfields if they do not match ISSN-format
sub remove_hyphens_except_issn {
    my ($record, $tag, $subfield_list) = @_;

    foreach $field ($record->field($tag)) {
        my @all_subfields = $field->subfields();
        $field->delete_subfield(match => qr/.*/);
        foreach my $subf (@all_subfields) {
            foreach my $code (@{$subfield_list}) {
                if ($subf->[0] eq $code) {
                    if (!has_issn_format($subf->[1])) {
                        $subf->[1] =~ s/-//g;
                    }
                }
            }
            $field->add_subfields($subf->[0] => $subf->[1]);
        }
    }
    return $record;
}

# Check if value matches ISSN-format (####-###X)
sub has_issn_format {
    my ($value) = @_;
    if ($value =~ /^\d\d\d\d-\d\d\d[\dXx]$/) {
        return 1;
    }
    return 0;
}

1;

