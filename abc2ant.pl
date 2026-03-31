#!/usr/bin/perl
use strict;
use warnings;

print ";;; AntVM65 Generated Assembly\n";

while (<>) {
    chomp;
    s/%.*//;            # Strip ABC comments
    next if /^\s*$/;    # Skip empty lines

    # Handle Procedure Definitions ($foo:)
    if (/^\$([a-zA-Z0-9_]+):/) {
        print ".proc $1\n";
        next;
    }

    # Tokenize by whitespace
    my @tokens = split(/\s+/, $_);

    foreach my $token (@tokens) {
        next if $token eq "";

        # CASE: Channel Select (|ABC) - Explicit hardware routing
        if ($token =~ /^\|([ABCN]+)$/) {
            my $channels = $1;
            my %ch_map = (A => 0, B => 1, C => 2, N => 3);
            foreach my $char (split //, $channels) {
                printf "  .byte \$%02X  ;; %s (CHANNEL %s)\n", 0xD8 + $ch_map{$char}, $token, $char;
            }
        }

        # CASE: Voice/Instrument (V:3) - Orthogonal logical setup
        elsif ($token =~ /^V:(\d+)$/) {
            # TODO: Generate command to load instrument/delta presets for Voice $1
            printf "  ;; TODO: .byte \$XX  ;; %s (Load Instrument %d Deltas)\n", $token, $1;
        }

        # CASE: Dynamic Markings (!f!) - Discrete volume
        elsif ($token =~ /^!(p|pp|ppp|mp|mf|f|ff|fff)!$/) {
            # TODO: Generate SETAY or dynamic level command
            printf "  ;; TODO: .byte \$E8, \$XX  ;; %s\n", $token;
        }

        # CASE: Hairpins (< or >) - Gradual volume shifts
        elsif ($token =~ /^([<>]+)$/) {
            # TODO: Trigger Volume Envelope Step Up/Down
            printf "  ;; TODO: .byte \$XX  ;; %s (Crescendo/Decrescendo)\n", $token;
        }

        # CASE: Explicit VM Commands (No spaces allowed: WAIT10)
        elsif ($token =~ /^(WAIT|VALUE)(\d+)$/) {
            my $hex = ($1 eq "WAIT") ? 0xC0 | ($2 & 0x0F) : 0xC8 | ($2 & 0x07);
            printf "  .byte \$%02X  ;; %s\n", $hex, $token;
        }

        # CASE: ABC Notes (Standard parsing)
        elsif ($token =~ /^([_^=]?)([A-Ga-g])([,']*)(\d*)$/) {
            # (Note/Octave/Duration logic here...)
            printf "  .byte \$XX  ;; %s\n", $token;
        }

        # CASE: RET
        elsif ($token eq "RET") {
            printf "  .byte \$FF  ;; %s\n", $token;
            print ".endproc\n\n";
        }
    }
}
