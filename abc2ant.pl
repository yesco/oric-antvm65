#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration & State ---
my %note_map   = (C=>0, D=>4, E=>8, F=>10, G=>14, A=>18, B=>22); 
my @octave_map = (4, 4, 4, 4); 
my @active_ch  = (0);          
my $base_len   = 1.0; 

my %vol_map = (
    'ppp' => 2, 'pp' => 4, 'p' => 6, 'mp' => 8, 
    'mf' => 10, 'f' => 12, 'ff' => 14, 'fff' => 15
);

print ";;; AntVM65 Generated Assembly\n\n";

while (<>) {
    s/%.*//; 
    chomp;
    my $line_num = $.;
    my $filename = $ARGV || "stdin";
    s/^\s+|\s+$//g; 
    next if /^$/;

    if (/^\$([a-zA-Z0-9_]+):/) {
        print ".proc $1\n";
        next;
    }

    foreach my $token (split(/\s+/, $_)) {
        next if $token eq "";

        if ($token =~ /^\|([ABCN]+)$/) {
            my %ch_map = (A=>0, B=>1, C=>2, N=>3);
            @active_ch = map { $ch_map{$_} } split //, $1;
            foreach my $ch (@active_ch) {
                printf "  .byte %%11011%03b ;; %-14s (Select %s)\n", $ch, $token, (qw/A B C N/)[$ch];
            }
        }
        elsif ($token =~ /^([:|\][\|]+)$/) {
            printf "  %-18s ;; %-14s (Bar line)\n", "  ", $token;
        }
        elsif ($token =~ /^\$([a-zA-Z0-9_]+)$/) {
            printf "  .byte %%11110000 ;; %-14s (CALL %s)\n", $token, $1;
        }
        elsif ($token =~ /^!([a-z]+)!$/i) {
            my $v = $vol_map{lc($1)} || 7;
            printf "  .byte %%10111%03b ;; TODO: VOL %-7d (from %s)\n", $v & 0x07, $v, $token;
        }
        elsif ($token =~ /^(K|L|Q|TPS|BPM):(.+)$/i || $token =~ /^(bass|treble|OCT[+-])$/i) {
            handle_metadata($token);
        }
        elsif ($token =~ /^(WAIT|VALUE|VOL)(\d+)$/) {
            my %pre = (WAIT=>"11000", VALUE=>"11001", VOL=>"10111");
            printf "  .byte %%%s%03b ;; %-14s (Value: %d)\n", $pre{$1}, $2 & 0x07, $token, $2;
        }
        elsif ($token eq "RET") {
            printf "  .byte %%11111111 ;; %-14s\n.endproc\n\n", $token;
        }
        elsif ($token =~ /^[A-Ga-gzx\[\.\^\/_]/) {
            my $working = $token;
            while ($working ne "") {
                my $staccato = ($working =~ s/^\.//) ? 1 : 0;
                if ($staccato) { printf "  %-18s ;; TODO: STACCATO ON  (Next note short)\n", "  "; }

                # Chord Eater - Fixed Note Extraction
                if ($working =~ s/^\[(.+?)\](\d*(?:\/\d+)?\.?)?//) {
                    my ($notes_raw, $chord_dur) = ($1, $2);
                    printf "  %-18s ;; TODO: [%-9s] (CHORD START)\n", "  ", $notes_raw;
                    # Extract full note string including accidentals and octave marks
                    my @chord_notes = ($notes_raw =~ /([_^=]*\/?(?:[A-Ga-g][,']*))/g);
                    foreach my $n (@chord_notes) { parse_note($n, $n, 1); }
                    my $final_dur = parse_duration($chord_dur) * $base_len;
                    printf "  .byte %%11000%03b ;; %-14s (Wait Chord: %.2f)\n", int($final_dur) & 0x07, "", $final_dur;
                    printf "  %-18s ;; %-14s (CHORD END)\n", "  ", "";
                }
                elsif ($working =~ s/^([_^=]*\/?)([A-Ga-g])([,']*)(\d*(?:\/\d+)?\.?|(?=-))//) {
                    my $n_str = $1 . $2 . $3 . $4;
                    my $tie = ($working =~ s/^-//) ? 1 : 0;
                    if ($tie) { printf "  .byte %%11001%03b ;; TODO: SUSTAIN %-4s (Tie logic)\n", 1, "ON"; }
                    parse_note($n_str, $n_str, 0);
                    if ($tie && $working !~ /^[A-G^=_]/i) { printf "  .byte %%11001%03b ;; TODO: SUSTAIN %-4s (Tie logic)\n", 0, "OFF"; }
                    if ($staccato) { printf "  %-18s ;; TODO: STACCATO OFF\n", "  "; }
                }
                elsif ($working =~ s/^([zx]+)(\d*(?:\/\d+)?\.?)?//i) {
                    my $total = length($1) * parse_duration($2) * $base_len;
                    printf "  .byte %%11000%03b ;; %-14s (Wait: %.2f)\n", int($total) & 0x07, $1 . ($2||""), $total;
                }
                else { last; }
            }
        }
    }
}

sub handle_metadata {
    my $token = shift;
    if ($token =~ /^L:(.+)$/i) {
        $base_len = parse_duration($1);
        printf "  %-18s ;; %-14s (Base Multiplier: %.2f)\n", "  ", $token, $base_len;
    }
    elsif ($token =~ /^(TPS|Q|BPM):(.+)$/i) {
        printf "  %-18s ;; TODO: %-10s (Value: %s)\n", "  ", $token, $2;
    }
    elsif ($token =~ /^OCT([+-])$/) {
        my $dir = $1 eq '+' ? 1 : -1;
        foreach my $ch (@active_ch) { 
            $octave_map[$ch] += $dir;
            $octave_map[$ch] = 0 if $octave_map[$ch] < 0;
            $octave_map[$ch] = 7 if $octave_map[$ch] > 7;
        }
        printf "  %-18s ;; %-14s (Octave now: %d)\n", "  ", $token, $octave_map[$active_ch[0]];
    }
    else {
        my $raw = $token; $raw =~ s/^K://i;
        my $oct = ($raw =~ /^\d+$/) ? $raw : (lc($raw) eq "bass" ? 2 : 4);
        foreach my $ch (@active_ch) { $octave_map[$ch] = $oct; }
        printf "  %-18s ;; %-14s (Base Octave: %d)\n", "  ", $token, $oct;
    }
}

sub parse_note {
    my ($note_token, $orig, $no_wait) = @_;
    # Strictly parse the provided token without re-declaring local variables that shadow inputs
    my ($acc, $n_char, $oct_mod, $dur_str) = ($note_token =~ /^([_^=]*\/?)([A-Ga-g])([,']*)(\d*(?:\/\d+)?\.?)$/);
    
    return unless defined $n_char;
    my $note = $note_map{uc($n_char)};

    if    ($acc eq '^')  { $note += 2; } 
    elsif ($acc eq '^/') { $note += 1; } 
    elsif ($acc eq '_')  { $note -= 2; } 
    elsif ($acc eq '_/') { $note -= 1; } 
    
    my $oct = $octave_map[$active_ch[0]]; 
    $oct++ if $n_char =~ /[a-z]/;
    $oct += length($oct_mod) if ($oct_mod && $oct_mod =~ /'/);
    $oct -= length($oct_mod) if ($oct_mod && $oct_mod =~ /,/);
    $oct = 0 if $oct < 0; $oct = 7 if $oct > 7;

    printf "  .byte %%%05b%03b ;; %-14s (Note:%d Oct:%d)\n", ($note & 0x1F), ($oct & 0x07), $orig, $note, $oct;
    unless ($no_wait) {
        my $final_dur = parse_duration($dur_str) * $base_len;
        printf "  .byte %%11000%03b ;; %-14s (Wait: %.2f)\n", int($final_dur) & 0x07, "", $final_dur;
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
