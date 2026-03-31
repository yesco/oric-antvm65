#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration & State ---
my %note_map   = (C=>0, D=>4, E=>8, F=>10, G=>14, A=>18, B=>22); 
my @octave_map = (4, 4, 4, 4); 
my @active_ch  = (0); 
my $base_len   = 1.0; 
my $manual_mode = 0; 

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
        my $working = $token;
        while ($working ne "") {
            if ($working =~ s/^\|([ABCN]+)//) {
                my $match = $1;
                my %ch_map = (A=>0, B=>1, C=>2, N=>3);
                @active_ch = map { $ch_map{$_} } split //, $match;
                foreach my $ch (@active_ch) {
                    printf "  .byte %%11011%03b ;; %-14s (Select %s)\n", $ch, "|$match", (qw/A B C N/)[$ch];
                }
            }
            elsif ($working =~ s/^([:|\][\|]+)//) {
                printf "  %-18s ;; %-14s (Bar line)\n", "  ", $1;
            }
            elsif ($working =~ s/^\$([a-zA-Z0-9_]+)//) {
                printf "  .byte %%11110000 ;; %-14s (CALL %s)\n", "\$$1", $1;
            }
            elsif ($working =~ s/^!([a-z]+)!//i) {
                my $match = $1;
                my $v = $vol_map{lc($match)} || 7;
                printf "  .byte %%10111%03b ;; TODO: VOL %-7d (from !%s!)\n", $v & 0x07, $v, $match;
            }
            elsif ($working =~ s/^(K|L|Q|TPS|BPM):([^\s!|()]+)//i || $working =~ s/^(bass|treble|OCT[+-])//i) {
                handle_metadata($1 . ($2 ? ":$2" : ""));
            }
            elsif ($working =~ s/^@([A-Z]+)(\d*(?:\/\d+)?)//) {
                my ($cmd, $val_str) = ($1, $2);
                my $val = 0;
                if ($val_str =~ /^\/(\d+)$/) {
                    my $denom = $1;
                    $val = int(log($denom)/log(2)) if $denom > 0;
                } elsif ($val_str =~ /^(\d+)$/) {
                    $val = $1;
                }
                
                my %pre = (WAIT=>"11000", VALUE=>"11001", VOL=>"10111", SUSTAIN=>"11001", LEGATO=>"11001");
                $manual_mode = ($cmd eq "SUSTAIN" || $cmd eq "LEGATO" || ($cmd eq "VALUE" && $val == 0)) ? 1 : 0;
                printf "  .byte %%%s%03b ;; %-14s (Ext: %s %s)\n", $pre{$cmd}||"11111", $val & 0x07, "@".$cmd.$val_str, $cmd, $val_str;
            }
            elsif ($working =~ s/^\[(.+?)\](\d*(?:\/\d+)?\.?)?//) {
                my ($notes_raw, $chord_dur) = ($1, $2);
                printf "  %-18s ;; TODO: [%-9s] (CHORD START)\n", "  ", $notes_raw;
                my @chord_notes = ($notes_raw =~ /([_^=]*\/?(?:[A-Ga-g][,']*))/g);
                foreach my $n (@chord_notes) { parse_note($n, $n, 1); }
                my $ppp = parse_music_wait($chord_dur);
                printf "  .byte %%11000%03b ;; %-14s (Wait Chord: 1/%d)\n", $ppp & 0x07, "", 2**$ppp if $ppp > 0;
                printf "  %-18s ;; %-14s (CHORD END)\n", "  ", "";
            }
            elsif ($working =~ s/^([_^=]*\/?)([A-Ga-g])([,']*)(\d*(?:\/\d+)?\.?|(?=-))//) {
                my $n_str = $1 . $2 . $3 . $4;
                my $tie = ($working =~ s/^-//) ? 1 : 0;
                if ($tie) { 
                    printf "  .byte %%11001000 ;; %-14s (VALUE 0: SUSTAIN ON)\n", "-";
                    $manual_mode = 1;
                }
                parse_note($n_str, $n_str, 0);
                if ($tie && $working !~ /^[A-G^=_]/i) { 
                    printf "  .byte %%11001010 ;; %-14s (VALUE 2: SUSTAIN OFF)\n", "-";
                    $manual_mode = 0;
                }
            }
            elsif ($working =~ s/^([zx]+)(\d*(?:\/\d+)?\.?)?//i) {
                my $ppp = parse_music_wait($2);
                printf "  .byte %%11000%03b ;; %-14s (Wait: 1/%d)\n", $ppp & 0x07, $1 . ($2||""), 2**$ppp if $ppp > 0;
            }
            elsif ($working =~ s/^(WAIT|VALUE|VOL)(\d+)//) {
                my ($cmd, $val) = ($1, $2);
                my %pre = (WAIT=>"11000", VALUE=>"11001", VOL=>"10111");
                $manual_mode = ($cmd eq "VALUE" && $val == 0) ? 1 : 0;
                printf "  .byte %%%s%03b ;; %-14s (Value: %d)\n", $pre{$cmd}, $val & 0x07, $cmd.$val, $val;
            }
            elsif ($working =~ s/^RET//) {
                printf "  .byte %%11111111 ;; %-14s\n.endproc\n\n", "RET";
            }
            else { $working = ""; }
        }
    }
}

sub handle_metadata {
    my $token = shift;
    if ($token =~ /^L:(.+)$/i) {
        $base_len = eval_frac($1);
        printf "  %-18s ;; %-14s (Base Multiplier: %.2f)\n", "  ", $token, $base_len;
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
        printf "  %-18s ;; %-14s (Base Octave: %d)\n", "  ", $token, $octave_map[$active_ch[0]];
    }
}

sub parse_note {
    my ($note_token, $orig, $no_wait) = @_;
    my ($acc, $n_char, $oct_mod, $dur_str) = ($note_token =~ /^([_^=]*\/?)([A-Ga-g])([,']*)(\d*(?:\/\d+)?\.?)$/);
    return unless defined $n_char;
    my $note = $note_map{uc($n_char)};
    if ($acc eq '^') { $note += 2; } elsif ($acc eq '^/') { $note += 1; }
    elsif ($acc eq '_') { $note -= 2; } elsif ($acc eq '_/') { $note -= 1; }
    my $oct = $octave_map[$active_ch[0]]; 
    $oct++ if $n_char =~ /[a-z]/;
    $oct += length($oct_mod) if ($oct_mod && $oct_mod =~ /'/);
    $oct -= length($oct_mod) if ($oct_mod && $oct_mod =~ /,/);
    $oct = 0 if $oct < 0; $oct = 7 if $oct > 7;
    printf "  .byte %%%05b%03b ;; %-14s (Note:%d Oct:%d)\n", ($note & 0x1F), ($oct & 0x07), $orig, $note, $oct;
    unless ($no_wait || $manual_mode) {
        my $ppp = parse_music_wait($dur_str);
        printf "  .byte %%11000%03b ;; %-14s (Auto-Wait: 1/%d)\n", $ppp & 0x07, "", 2**$ppp if $ppp > 0;
    }
}

sub parse_music_wait {
    my $str = shift || "";
    if ($str =~ /\/(\d+)/) {
        my $denom = $1;
        return int(log($denom)/log(2));
    }
    return 1 if $str =~ /2/; return 2 if $str =~ /4/; return 3 if $str =~ /8/; 
    return 4 if $str =~ /16/; return 5 if $str =~ /32/; return 0;
}

sub eval_frac {
    my $str = shift;
    if ($str =~ /^(\d+)\/(\d+)$/) { return $1 / $2; }
    return $str || 1.0;
}
