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

    my @tokens = split(/\s+/, $_);
    foreach my $token (@tokens) {
        next if $token eq "" || $token eq "|";

        # CASE: Headers, Octave Shifts, and Metadata
        if ($token =~ /^(K|L|Q|TPS|BPM):(.+)$/i || $token =~ /^(bass|treble|OCT[+-])$/i) {
            my $tag = $1 || "";
            my $val = $2 || "";

            if (uc($tag) eq 'L') {
                $base_len = parse_duration($val);
                printf "  %-18s ;; L:%-10s (Base Multiplier: %.2f)\n", "", $val, $base_len;
            }
            elsif (uc($tag) eq 'TPS' || uc($tag) eq 'Q' || uc($tag) eq 'BPM' || $token =~ /^BPM:/) {
                my $v = $val || ($token =~ /:(.+)$/ ? $1 : "");
                printf "  %-18s ;; TODO: %-10s (Value: %s)\n", "", $token, $v;
            }
            elsif ($token =~ /^OCT([+-])$/) {
                my $dir = $1 eq '+' ? 1 : -1;
                foreach my $ch (@active_ch) { 
                    $octave_map[$ch] += $dir;
                    $octave_map[$ch] = 0 if $octave_map[$ch] < 0;
                    $octave_map[$ch] = 7 if $octave_map[$ch] > 7;
                }
                printf "  %-18s ;; OCT%-12s (Octave now: %d)\n", "", $1, $octave_map[$active_ch[0]];
            }
            else {
                my $raw = $val || $token; $raw =~ s/^K://i;
                my $oct = ($raw =~ /^\d+$/) ? $raw : (lc($raw) eq "bass" ? 2 : 4);
                foreach my $ch (@active_ch) { $octave_map[$ch] = $oct; }
                printf "  %-18s ;; %-14s (Base Octave: %d)\n", "", $token, $oct;
            }
            next;
        }

        # CASE: Dynamics
        if ($token =~ /^!([a-z]+)!$/i) {
            my $code = lc($1);
            if (exists $vol_map{$code}) {
                my $v = $vol_map{$code};
                printf "  .byte %%10111%03b ;; TODO: VOL %-7d (from %s)\n", $v & 0x07, $v, $token;
            } else {
                printf "  %-18s ;; TODO: FAIL: %-10s (Unknown decoration)\n", "", $token;
            }
            next;
        }

        # CASE: Channel Select
        if ($token =~ /^\|([ABCN]+)$/) {
            my %ch_map = (A=>0, B=>1, C=>2, N=>3);
            @active_ch = map { $ch_map{$_} } split //, $1;
            foreach my $ch (@active_ch) {
                printf "  .byte %%11011%03b ;; %-14s (Select %s)\n", $ch, $token, (qw/A B C N/)[$ch];
            }
            next;
        }

        # CASE: Ties (C-C)
        if ($token =~ /-/ && $token =~ /^[A-G^=_]/i) {
            my @parts = split(/-/, $token);
            foreach my $i (0..$#parts) {
                if ($i > 0) { printf "  .byte %%11001%03b ;; TODO: SUSTAIN ON  (Tie active)\n", 1; }
                parse_note($parts[$i], $token);
                if ($i == $#parts && $#parts > 0) { printf "  .byte %%11001%03b ;; TODO: SUSTAIN OFF (Tie ended)\n", 0; }
            }
            next;
        }

        # CASE: Single Note
        if ($token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*(?:\/\d+)?)(\.?)$/) {
            parse_note($token, $token);
            next;
        }

        # CASE: Rests
        if ($token =~ /^([zx]+)(\d*(?:\/\d+)?)$/i) {
            my $total = length($1) * parse_duration($2) * $base_len;
            printf "  .byte %%11000%03b ;; %-14s (Rest: %.2f)\n", int($total) & 0x07, $token, $total;
            next;
        }

        # CASE: Direct Commands
        if ($token =~ /^(WAIT|VALUE|VOL)(\d+)$/) {
            my %pre = (WAIT=>"11000", VALUE=>"11001", VOL=>"10111");
            printf "  .byte %%%s%03b ;; %-14s (Value: %d)\n", $pre{$1}, $2 & 0x07, $token, $2;
        }
        elsif ($token =~ /^CALL:([a-zA-Z0-9_]+)$/) {
            printf "  .byte %%11110000 ;; CALL %-11s (Subroutine)\n", $1;
        }
        elsif ($token eq "RET") {
            printf "  .byte %%11111111 ;; %-14s\n.endproc\n\n", $token;
        }
        else {
            printf STDERR "%%%s.%d: FAIL: \"%s\"\n", $filename, $line_num, $token;
        }
    }
}

sub parse_note {
    my ($note_token, $orig) = @_;
    $note_token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*(?:\/\d+)?)(\.?)$/;
    my ($acc, $n_char, $oct_mod, $dur_str, $dot) = ($1, $2, $3, $4, $5);
    
    my $note = $note_map{uc($n_char)};
    $note += 2 if ($acc && $acc eq '^'); $note -= 2 if ($acc && $acc eq '_');

    my $oct = $octave_map[$active_ch[0]]; 
    $oct++ if $n_char =~ /[a-z]/;
    $oct += length($oct_mod) if ($oct_mod && $oct_mod =~ /'/);
    $oct -= length($oct_mod) if ($oct_mod && $oct_mod =~ /,/);
    $oct = 0 if $oct < 0; $oct = 7 if $oct > 7;

    printf "  .byte %%%05b%03b ;; %-14s (Note:%d Oct:%d)\n", ($note & 0x1F), ($oct & 0x07), $orig, $note, $oct;

    my $final_dur = parse_duration($dur_str) * $base_len;
    $final_dur *= 1.5 if ($dot && $dot eq ".");
    
    printf "  .byte %%11000%03b ;; %-14s (Wait: %.2f)\n", int($final_dur) & 0x07, "", $final_dur;
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
