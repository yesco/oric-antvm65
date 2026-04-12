#!/usr/bin/perl
use strict;
use warnings;

my $output_file = 'music.ym';
my @frames;

# 1. Parse the input (ignores non-AY lines automatically)
while (<STDIN>) {
    # Matches "AY:" followed by 14 pairs of hex digits
    if (/AY:\s*([0-9a-fA-F\s]+)/) {
        my $hex_string = $1;
        # Extract the 14 hex bytes into an array
        my @bytes = map { hex($_) } ($hex_string =~ /([0-9a-fA-F]{2})/g);
        
        if (@bytes >= 14) {
            # Only keep the first 14 registers
            push @frames, [ @bytes[0..13] ];
        }
    }
}

my $num_frames = scalar @frames;
die "No AY data found in input!\n" if $num_frames == 0;

# 2. Write the YM3 file
open(my $fh, '>', $output_file) or die "Cannot open $output_file: $!";
binmode($fh);

# Header
print $fh "YM3!";

# 3. Interleaving Logic
# YM3 requires: [All R0s], [All R1s] ... [All R13s]
for my $reg_idx (0..13) {
    for my $frame_idx (0..$num_frames - 1) {
        # 'C' is an unsigned char (8-bit)
        print $fh pack('C', $frames[$frame_idx][$reg_idx]);
    }
}

close($fh);
print "Successfully converted $num_frames frames to $output_file\n";
