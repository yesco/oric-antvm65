#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration & State ---
my %note_map   = (C=>0, D=>4, E=>8, F=>10, G=>14, A=>18, B=>22); 
my @octave_map = (4, 4, 4, 4); 
my @active_ch  = (0);          

print ";;; AntVM65 Generated Assembly\n\n";

while (<>) {
    chomp;
    s/%.*//; s/^\s+|\s+$//g; 
    next if /^$/;

    # 1. Headers (Line-based)
    if (/^K:(\d+)$/) {
        my $val = $1;
        foreach my $ch (@active_ch) { $octave_map[$ch] = $val; }
        printf "                     ;; %-10s (Base Octave set)\n", "K:$val";
        next;
    }

    # 2. Procedures
    if (/^\$([a-zA-Z0-9_]+):/) {
        print ".proc $1\n";
        next;
    }

    # 3. Tokens
    foreach my $token (split(/\s+/, $_)) {
        next if $token eq "" || $token eq "|"; # Skip empty/bars

        # CASE: ABC Rests (z/x with numbers OR repeated zzz/xxx)
        if ($token =~ /^([zx]+)(\d*)$/) {
            my $chars = $1;
            my $multiplier = $2 || 1;
            my $total_ticks = length($chars) * $multiplier;
            
            my $bin = sprintf("%%11000%03b", $total_ticks & 0x07);
            printf "  .byte %-10s ;; %-10s (Rest: %d ticks)\n", $bin, $token, $total_ticks;
        }

        # CASE: Channel Select (|ABC)
        elsif ($token =~ /^\|([ABCN]+)$/) {
            my %map = (A=>0, B=>1, C=>2, N=>3);
            my @list = split //, $1;
            @active_ch = map { $map{$_} } @list;
            foreach my $ch (@active_ch) {
                my $bin = sprintf("%%11011%03b", $ch);
                printf "  .byte %-10s ;; %-10s (Select %s)\n", $bin, $token, (qw/A B C N/)[$ch];
            }
        }

        # CASE: ABC Notes (nnnnn ooo)
        elsif ($token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*)$/) {
            my ($acc, $n_char, $oct_mod, $dur) = ($1, $2, $3, $4);
            my $note = $note_map{uc($n_char)};
            $note += 2 if $acc eq '^'; 
            $note -= 2 if $acc eq '_'; 

            my $oct = $octave_map[$active_ch[0]]; # Reference lead channel
            $oct++ if $n_char =~ /[a-z]/;
            $oct += length($oct_mod) if $oct_mod =~ /'/;
            $oct -= length($oct_mod) if $oct_mod =~ /,/;
            $oct = 0 if $oct < 0; $oct = 7 if $oct > 7;

            my $val = sprintf("%%%08b", (($note & 0x1F) << 3) | ($oct & 0x07));
            printf "  .byte %-10s ;; %-10s (Note:%d Oct:%d)\n", $val, $token, $note, $oct;

            if ($dur ne "") {
                my $w_bin = sprintf("%%11000%03b", $dur & 0x07);
                printf "  .byte %-10s ;; %-10s (Wait for %s)\n", $w_bin, "", $token;
            }
        }

        # CASE: Explicit Commands (WAIT/VALUE)
        elsif ($token =~ /^(WAIT|VALUE)(\d+)$/) {
            my $prefix = ($1 eq "WAIT") ? "11000" : "11001";
            my $bin = sprintf("%%%s%03b", $prefix, $2 & 0x07);
            printf "  .byte %-10s ;; %-10s\n", $bin, $token;
        }

        # CASE: Return
        elsif ($token eq "RET") {
            printf "  .byte %%11111111 ;; %-10s\n.endproc\n\n", $token;
        }

        # FALLBACK: Failure
        else {
            my $err = ";; FAIL: $token";
            printf "  %-18s ;; Unknown Token\n", $err;
            print STDERR "AntVM65 Error: Unknown token '$token' at line $.\n";
        }
    }
}
