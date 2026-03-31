#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration & State ---
my %note_map   = (C=>0, D=>4, E=>8, F=>10, G=>14, A=>18, B=>22); 
my @octave_map = (4, 4, 4, 4); 
my @active_ch  = (0);          
my $base_len   = 1;  

print ";;; AntVM65 Generated Assembly\n\n";

while (<>) {
    s/%.*//; # Strip comments
    chomp;
    my $line_num = $.;
    my $filename = $ARGV || "stdin";
    
    s/^\s+|\s+$//g; 
    next if /^$/;

    # 1. Procedures / Labels (Line-based)
    if (/^\$([a-zA-Z0-9_]+):/) {
        print ".proc $1\n";
        next;
    }

    # 2. Tokenize the line
    my @tokens = split(/\s+/, $_);
    foreach my $token (@tokens) {
        next if $token eq "" || $token eq "|";

        # CASE: Headers (K:, L:, Q:, TPS:)
        if ($token =~ /^(K|L|Q|TPS):(.+)$/i || $token =~ /^(bass|treble)$/i) {
            my ($type, $val) = ($1, $2);
            
            if (defined $type && uc($type) eq 'L') {
                $base_len = $val;
                printf "                     ;; L:%-10s (Base Length set)\n", $val;
            }
            elsif (defined $type && uc($type) eq 'Q') {
                printf "                     ;; TODO: Q:%-8s (BPM Set)\n", $val;
            }
            elsif (defined $type && uc($type) eq 'TPS') {
                printf "                     ;; TODO: TPS:%-6s (Ticks/Sec Set)\n", $val;
            }
            else {
                # Octave / Key Logic (K:4, K:bass, or just "bass")
                my $raw = $val || $token;
                $raw =~ s/^K://i;
                my $oct = ($raw =~ /^\d+$/) ? $raw : (lc($raw) eq "bass" ? 2 : 4);
                foreach my $ch (@active_ch) { $octave_map[$ch] = $oct; }
                printf "                     ;; %-10s (Base Octave: %d)\n", $token, $oct;
            }
            next;
        }

        # CASE: Channel Select (|ABC)
        if ($token =~ /^\|([ABCN]+)$/) {
            my %ch_map = (A=>0, B=>1, C=>2, N=>3);
            @active_ch = map { $ch_map{$_} } split //, $1;
            foreach my $ch (@active_ch) {
                printf "  .byte %%11011%03b ;; %-10s (Select %s)\n", $ch, $token, (qw/A B C N/)[$ch];
            }
            next;
        }

        # CASE: Rests (z, z4, z1/4)
        if ($token =~ /^([zx]+)(\d*(?:\/\d+)?)$/i) {
            my $multiplier = parse_duration($2);
            my $total = length($1) * $multiplier * $base_len;
            printf "  .byte %%11000%03b ;; %-10s (Rest: %d)\n", int($total) & 0x07, $token, $total;
            next;
        }

        # CASE: Notes (C, ^C, c', C1/4, C.)
        if ($token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*(?:\/\d+)?)(\.?)$/) {
            my ($acc, $n_char, $oct_mod, $dur_str, $dot) = ($1, $2, $3, $4, $5);
            my $note = $note_map{uc($n_char)};
            $note += 2 if $acc eq '^'; $note -= 2 if $acc eq '_';

            my $oct = $octave_map[$active_ch[0]]; 
            $oct++ if $n_char =~ /[a-z]/;
            $oct += length($oct_mod) if $oct_mod =~ /'/;
            $oct -= length($oct_mod) if $oct_mod =~ /,/;
            $oct = 0 if $oct < 0; $oct = 7 if $oct > 7;

            printf "  .byte %%%05b%03b ;; %-10s (Note:%d Oct:%d)\n", ($note & 0x1F), ($oct & 0x07), $token, $note, $oct;

            my $mult = parse_duration($dur_str);
            my $final_dur = $mult * $base_len;
            $final_dur = int($final_dur * 1.5) if $dot eq ".";
            
            if ($final_dur > 0) {
                printf "  .byte %%11000%03b ;; %-10s (Wait %d)\n", int($final_dur) & 0x07, "", $final_dur;
            }
            next;
        }

        # CASE: Control Commands
        if ($token =~ /^(WAIT|VALUE|VOL)(\d+)$/) {
            my %pre = (WAIT=>"11000", VALUE=>"11001", VOL=>"10111");
            printf "  .byte %%%s%03b ;; %-10s\n", $pre{$1}, $2 & 0x07, $token;
        }
        elsif ($token =~ /^CALL:([a-zA-Z0-9_]+)$/) {
            printf "  .byte %%11110000 ;; CALL %s\n", $1;
        }
        elsif ($token eq "RET") {
            printf "  .byte %%11111111 ;; %-10s\n.endproc\n\n", $token;
        }
        else {
            printf STDERR "%%%s.%d: FAIL: \"%s\"\n", $filename, $line_num, $token;
        }
    }
}

sub parse_duration {
    my $str = shift || "";
    return 1 if $str eq "";
    if ($str =~ /^(\d+)\/(\d+)$/) { return $1 / $2; }
    if ($str =~ /^\/(\d+)$/)      { return 1 / $1; }
    if ($str =~ /^\/$/)           { return 0.5; }
    if ($str =~ /^(\d+)$/)        { return $1; }
    return 1;
}
