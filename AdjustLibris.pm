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

1;

