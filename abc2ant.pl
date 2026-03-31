#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration & State ---
# 24-TET: 2 units = semitone. C=0, C#=2, D=4... B=22.
my %note_map   = (C=>0, D=>4, E=>8, F=>10, G=>14, A=>18, B=>22); 
my @octave_map = (4, 4, 4, 4); # Default Octave 4 for A, B, C, N
my @active_ch  = (0);          # Default to Channel A

print ";;; AntVM65 Generated Assembly (Format: nnnnn ooo)\n";

while (<>) {
    chomp;
    s/%.*//; s/^\s+|\s+$//g; # Clean line/comments
    next if /^$/;

    # CASE: Header K:n (Sets base octave for active channels)
    if (/^K:(\d+)$/) {
        my $val = $1;
        foreach my $ch (@active_ch) { $octave_map[$ch] = $val; }
        printf "  ;; K:%d (Base Octave set for active channels)\n", $val;
        next;
    }

    # CASE: Procedure Definition
    if (/^\$([a-zA-Z0-9_]+):/) {
        print ".proc $1\n";
        next;
    }

    foreach my $token (split(/\s+/, $_)) {
        next if $token eq "";

        # CASE: Channel Select (|ABC)
        if ($token =~ /^\|([ABCN]+)$/) {
            my %map = (A=>0, B=>1, C=>2, N=>3);
            @active_ch = map { $map{$_} } split //, $1;
            foreach my $ch (@active_ch) {
                # 11 011 xxx (D8-DB)
                printf "  .byte %%11011%03b  ;; %s (Select %s)\n", $ch, $token, (qw/A B C N/)[$ch];
            }
        }

        # CASE: ABC Notes (24-TET logic)
        elsif ($token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*)$/) {
            my ($acc, $n_char, $oct_mod, $dur) = ($1, $2, $3, $4);
            
            # 1. Calculate Note (0-23)
            my $note = $note_map{uc($n_char)};
            $note += 2 if $acc eq '^'; # Sharp +2 (semitone)
            $note -= 2 if $acc eq '_'; # Flat  -2 (semitone)

            # 2. Calculate Octave (0-7)
            my $oct = $octave_map[$active_ch[0]]; 
            $oct++ if $n_char =~ /[a-z]/;         # lowercase = octave up
            $oct += length($oct_mod) if $oct_mod =~ /'/;
            $oct -= length($oct_mod) if $oct_mod =~ /,/;
            $oct = 0 if $oct < 0; $oct = 7 if $oct > 7;

            # 3. Pack: nnnnn ooo
            my $bin_val = (($note & 0x1F) << 3) | ($oct & 0x07);
            printf "  .byte %%%08b  ;; %s (Note:%d Oct:%d)\n", $bin_val, $token, $note, $oct;

            # 4. Handle Duration (WAIT)
            if ($dur ne "") {
                # 11 000 www
                printf "  .byte %%11000%03b  ;; (WAIT %s)\n", $dur, $token;
            }
        }

        # CASE: Explicit Commands
        elsif ($token =~ /^(WAIT|VALUE)(\d+)$/) {
            my $prefix = ($1 eq "WAIT") ? "11000" : "11001";
            printf "  .byte %%%s%03b  ;; %s\n", $prefix, $2, $token;
        }

        # CASE: Return
        elsif ($token eq "RET") {
            print "  .byte %11111111  ;; RET\n.endproc\n\n";
        }

        # TODO placeholders
        elsif ($token =~ /^V:(\d+)$/ || $token =~ /^!(.*)!$/ || $token =~ /^[<>]+$/) {
            printf "  ;; TODO: .byte %%XXXXXXXX ;; %s\n", $token;
        }
    }
}
