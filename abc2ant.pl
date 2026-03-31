#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration & State ---
my %note_map   = (C=>0, D=>4, E=>8, F=>10, G=>14, A=>18, B=>22); 
my @octave_map = (4, 4, 4, 4); 
my @active_ch  = (0);          
my $base_len   = 1;  # From L: header
my $current_vol = 7;

print ";;; AntVM65 Generated Assembly\n\n";

while (<>) {
    s/%.*//; # Skip comments
    chomp;
    my $line = $_;
    s/^\s+|\s+$//g; 
    next if /^$/;

    # 1. Headers (Q, L, K, TPS, bass/treble)
    if (/^Q:\s*(\d+)/) { printf "                     ;; Q:%-8d (BPM)\n", $1; next; }
    if (/^TPS:\s*(\d+)/) { printf "                     ;; TPS:%-6d (Ticks/Sec)\n", $1; next; }
    if (/^L:\s*(\d+)/) { $base_len = $1; next; }
    if (/^(?:K:)?(bass|treble|\d+)$/i) {
        my $val = $1;
        my $oct = ($val =~ /^\d+$/) ? $val : (lc($val) eq "bass" ? 2 : 4);
        foreach my $ch (@active_ch) { $octave_map[$ch] = $oct; }
        printf "                     ;; %-10s (Base Octave: %d)\n", $line, $oct;
        next;
    }

    # 2. Procedures / Labels
    if (/^\$([a-zA-Z0-9_]+):/) {
        print ".proc $1\n";
        next;
    }

    # 3. Tokens
    foreach my $token (split(/\s+/, $_)) {
        next if $token eq "" || $token eq "|";

        # CASE: Calls & Returns
        if ($token =~ /^CALL:([a-zA-Z0-9_]+)$/) {
            printf "  .byte %%11110000 ;; CALL %s (Custom Op)\n", $1;
            next;
        }
        if ($token eq "RET") {
            printf "  .byte %%11111111 ;; %-10s\n.endproc\n\n", $token;
            next;
        }

        # CASE: Rests (z, zzz, x4)
        if ($token =~ /^([zx]+)(\d*)$/i) {
            my $total = length($1) * ($2 || 1) * $base_len;
            printf "  .byte %%11000%03b ;; %-10s (Rest: %d)\n", $total & 0x07, $token, $total;
        }

        # CASE: Channel Select (|ABC)
        elsif ($token =~ /^\|([ABCN]+)$/) {
            my %map = (A=>0, B=>1, C=>2, N=>3);
            @active_ch = map { $map{$_} } split //, $1;
            foreach my $ch (@active_ch) {
                printf "  .byte %%11011%03b ;; %-10s (Select %s)\n", $ch, $token, (qw/A B C N/)[$ch];
            }
        }

        # CASE: Note Parsing (with Dotted Rhythm support)
        elsif ($token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*)(\.?)$/) {
            my ($acc, $n_char, $oct_mod, $dur, $dot) = ($1, $2, $3, $4, $5);
            my $note = $note_map{uc($n_char)};
            $note += 2 if $acc eq '^'; $note -= 2 if $acc eq '_';

            my $oct = $octave_map[$active_ch[0]]; 
            $oct++ if $n_char =~ /[a-z]/;
            $oct += length($oct_mod) if $oct_mod =~ /'/;
            $oct -= length($oct_mod) if $oct_mod =~ /,/;
            $oct = 0 if $oct < 0; $oct = 7 if $oct > 7;

            my $val = sprintf("%%%08b", (($note & 0x1F) << 3) | ($oct & 0x07));
            printf "  .byte %-10s ;; %-10s (Note:%d Oct:%d)\n", $val, $token, $note, $oct;

            # Calculate Wait
            my $final_dur = ($dur eq "" ? 1 : $dur) * $base_len;
            $final_dur = int($final_dur * 1.5) if $dot eq ".";
            
            if ($final_dur > 0) {
                printf "  .byte %%11000%03b ;; %-10s (Wait %d)\n", $final_dur & 0x07, "", $final_dur;
            }
        }

        # CASE: Commands (WAIT/VALUE/VOL)
        elsif ($token =~ /^(WAIT|VALUE|VOL)(\d+)$/) {
            my %pre = (WAIT=>"11000", VALUE=>"11001", VOL=>"10111");
            printf "  .byte %%%s%03b ;; %-10s\n", $pre{$1}, $2 & 0x07, $token;
            # printf "  ;; .byte %%%s%03b ;; Commented version of %s\n", $pre{$1}, $2 & 0x07, $token;
        }

        # FALLBACK: Error
        else {
            my $fn = $ARGV || "stdin";
            printf STDERR "%%%s.%d: FAIL: \"%s\"\n", $fn, $., $token;
        }
    }
}
