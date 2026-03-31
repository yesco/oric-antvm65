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

    if (/^K:(\d+)$/) {
        my $val = $1;
        foreach my $ch (@active_ch) { $octave_map[$ch] = $val; }
        printf "                     ;; K:%d (Base Octave set)\n", $val;
        next;
    }

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
                my $bin = sprintf("%%11011%03b", $ch);
                printf "  .byte %-10s  ;; %s (Select %s)\n", $bin, $token, (qw/A B C N/)[$ch];
            }
        }

        # CASE: ABC Notes (nnnnn ooo)
        elsif ($token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*)$/) {
            my ($acc, $n_char, $oct_mod, $dur) = ($1, $2, $3, $4);
            my $note = $note_map{uc($n_char)};
            $note += 2 if $acc eq '^'; 
            $note -= 2 if $acc eq '_'; 

            my $oct = $octave_map[$active_ch[0]]; 
            $oct++ if $n_char =~ /[a-z]/;
            $oct += length($oct_mod) if $oct_mod =~ /'/;
            $oct -= length($oct_mod) if $oct_mod =~ /,/;
            $oct = 0 if $oct < 0; $oct = 7 if $oct > 7;

            my $val = sprintf("%%%08b", (($note & 0x1F) << 3) | ($oct & 0x07));
            printf "  .byte %-10s  ;; %s (Note:%d Oct:%d)\n", $val, $token, $note, $oct;

            if ($dur ne "") {
                my $w_bin = sprintf("%%11000%03b", $dur);
                printf "  .byte %-10s  ;; (WAIT for %s)\n", $w_bin, $token;
            }
        }

        # CASE: Explicit Commands (WAIT/VALUE)
        elsif ($token =~ /^(WAIT|VALUE)(\d+)$/) {
            my $prefix = ($1 eq "WAIT") ? "11000" : "11001";
            my $bin = sprintf("%%%s%03b", $prefix, $2);
            printf "  .byte %-10s  ;; %s\n", $bin, $token;
        }

        # CASE: Return
        elsif ($token eq "RET") {
            printf "  .byte %%11111111  ;; %s\n.endproc\n\n", $token;
        }

        # TODO placeholders
        elsif ($token =~ /^V:(\d+)$/ || $token =~ /^!(.*)!$/ || $token =~ /^[<>]+$/) {
            printf "  ;; TODO: %-8s  ;; %s\n", ".byte", $token;
        }
    }
}
