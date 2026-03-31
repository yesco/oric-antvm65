#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration & State ---
my %note_map   = (C=>0, D=>4, E=>8, F=>10, G=>14, A=>18, B=>22); 
my @octave_map = (4, 4, 4, 4); 
my @active_ch  = (0);          
my $base_len   = 1;  
my $current_vol = 7;

print ";;; AntVM65 Generated Assembly\n\n";

while (<>) {
    s/%.*//; # 1. Strip comments immediately
    chomp;
    my $line_num = $.;
    my $filename = $ARGV || "stdin";
    
    s/^\s+|\s+$//g; 
    next if /^$/;

    # 2. Procedures / Labels (Line-based)
    if (/^\$([a-zA-Z0-9_]+):/) {
        print ".proc $1\n";
        next;
    }

    # 3. Tokenize the line
    my @tokens = split(/\s+/, $_);
    foreach my $token (@tokens) {
        next if $token eq "" || $token eq "|";

        # CASE: Headers (K:4, L:1, Q:120, bass, etc.)
        if ($token =~ /^(?:K:|L:|Q:|TPS:)?(bass|treble|\d+[\/]?\d*)$/i) {
            if ($token =~ /^L:(\d+)/) { $base_len = $1; next; }
            if ($token =~ /^Q:/ || $token =~ /^TPS:/) { next; } # Parse but skip for now
            
            # Octave Logic
            my ($val) = ($token =~ /:?(.+)$/);
            my $oct = ($val =~ /^\d+$/) ? $val : (lc($val) eq "bass" ? 2 : 4);
            foreach my $ch (@active_ch) { $octave_map[$ch] = $oct; }
            printf "                     ;; %-10s (Base Octave: %d)\n", $token, $oct;
        }

        # CASE: Channel Select (|ABC or |A)
        elsif ($token =~ /^\|([ABCN]+)$/) {
            my %ch_map = (A=>0, B=>1, C=>2, N=>3);
            my @chars = split //, $1;
            @active_ch = map { $ch_map{$_} } @chars;
            foreach my $ch (@active_ch) {
                printf "  .byte %%11011%03b ;; %-10s (Select %s)\n", $ch, $token, (qw/A B C N/)[$ch];
            }
        }

        # CASE: Rests (z, z4, z1/4)
        elsif ($token =~ /^([zx]+)(\d*(?:\/\d+)?)$/i) {
            my $multiplier = parse_duration($2);
            my $total = length($1) * $multiplier * $base_len;
            printf "  .byte %%11000%03b ;; %-10s (Rest: %d)\n", int($total) & 0x07, $token, $total;
        }

        # CASE: Notes (C, ^C, c', C1/4, C.)
        elsif ($token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*(?:\/\d+)?)(\.?)$/) {
            my ($acc, $n_char, $oct_mod, $dur_str, $dot) = ($1, $2, $3, $4, $5);
            my $note = $note_map{uc($n_char)};
            $note += 2 if $acc eq '^'; $note -= 2 if $acc eq '_';

            # Use first active channel for octave context
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
        }

        # CASE: Control Commands
        elsif ($token =~ /^(WAIT|VALUE|VOL)(\d+)$/) {
            my %pre = (WAIT=>"11000", VALUE=>"11001", VOL=>"10111");
            printf "  .byte %%%s%03b ;; %-10s\n", $pre{$1}, $2 & 0x07, $token;
        }
        elsif ($token =~ /^CALL:([a-zA-Z0-9_]+)$/) {
            printf "  .byte %%11110000 ;; CALL %s\n", $1;
        }
        elsif ($token eq "RET") {
            printf "  .byte %%11111111 ;; %-10s\n.endproc\n\n", $token;
        }

        # FALLBACK: Error
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
