#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;

# Setup options: -r for raw binary mode
my %opts;
getopts('r', \%opts);

usage() unless @ARGV == 2;

my ($input_path, $output_path) = @ARGV;
my @frames;

# 1. Open Input (Handle '-' for STDIN)
my $in_fh;
if ($input_path eq '-') {
    $in_fh = \*STDIN;
} else {
    open($in_fh, '<', $input_path) or die "Error: Cannot open input '$input_path': $!\n";
}
binmode($in_fh) if $opts{r};

# 2. Extract Data
if ($opts{r}) {
    # RAW MODE: Read 14-byte chunks directly
    while (read($in_fh, my $buffer, 14)) {
        if (length($buffer) == 14) {
            push @frames, [ unpack('C14', $buffer) ];
        }
    }
} else {
    # TEXT MODE: Parse AY: hex lines
    while (<$in_fh>) {
        if (/AY:\s*([0-9a-fA-F\s]+)/) {
            my @bytes = ($1 =~ /([0-9a-fA-F]{2})/g);
            if (@bytes >= 14) {
                push @frames, [ map { hex($_) } @bytes[0..13] ];
            }
        }
    }
}
close($in_fh) unless $input_path eq '-';

# 3. Write Output
my $num_frames = scalar @frames;
die "Error: No AY data found!\n" if $num_frames == 0;

open(my $out_fh, '>', $output_path) or die "Error: Cannot open output '$output_path': $!\n";
binmode($out_fh);

print $out_fh "YM3!";
for my $reg_idx (0..13) {
    for my $f_idx (0..$num_frames - 1) {
        print $out_fh pack('C', $frames[$f_idx][$reg_idx]);
    }
}
close($out_fh);

print "Done! Processed $num_frames frames into $output_path\n";

sub usage {
    print "Usage: perl $0 [-r] <input_file> <output_file>\n";
    print "  <input_file>  Use '-' for STDIN\n";
    print "  -r            Raw mode (input is binary 14-byte repeated chunks)\n";
    exit 1;
}
