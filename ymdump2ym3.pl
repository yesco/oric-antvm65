#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;

# Setup options: -r for raw binary mode
my %opts;
getopts('r', \%opts);
getopts('f', \%opts);

usage() unless @ARGV == 2;

my ($input_path, $output_path) = @ARGV;
my @frames;

# 1. Open Input (Handle '-' for STDIN)
my $in_fh;
if ($input_path eq '-') {
    $in_fh = \*STDIN;
} else {
    open($in_fh, '<', $input_path) or die "Error: Cannot open input '$input_path': $!\n";
}
binmode($in_fh) if $opts{r};

# 2. Extract Data
if ($opts{r}) {
    # RAW MODE: Read 14-byte chunks directly
    while (read($in_fh, my $buffer, 14)) {
        if (length($buffer) == 14) {
            push @frames, [ unpack('C14', $buffer) ];
        }
    }
} else {
    # TEXT MODE: Parse AY: hex lines
    # TEXT MODE: Parse sox synth lines
    while (<$in_fh>) {
	# AntVM AY: ex hexhex hex aoutput
        if (/AY:\s*([0-9a-fA-F\s]+)/) {
            my @bytes = ($1 =~ /([0-9a-fA-F]{2})/g);
            if (@bytes >= 14) {
                push @frames, [ map { hex($_) } @bytes[0..13] ];
            }

	    next;
        }

	# war.f output - play 3 dom freq
	print ">$_";
	my $s= $_;
	my $n= 3;
	my @bytes= (0) x 14;
	my $mixer= 0b111111;
	my $got= 0;
	while(/v(\d+)N?(\d*)\s+([.0-9]+)hz/ig) {
	    $got++;
	    my ($v,$noise,$f) = ($1,$2,$3);

	    print "---- >$v< >$noise< >$f<\n";

	    $f=1 if +$f==0;
    	    my $p= int(1000000/16/+$f + 0.5);

	    my $hi= int($p/256);
	    my $lo= $p % 256;

	    # TODO:
$noise= undef;
	    
	    $bytes[11]= 0+($noise || 0);
	    if ($noise) {
		#print "$v\t$noise\t$f\n";
		#		$mixer &= 0b000111;
		$mixer &= 0b011111;
		# on all but sounds random
		#		$mixer &= 0b000111;

		# force volume
#		$v=15;
	    }

	    # volume 1v-150v (?) what meaning, is linear?
	    # ay volume is log
	    my $yv = $v;
#	    if (1) {
#	    } elsif ($v < 1000) {
#		$yv= int(log($v)/log(10)*30 + 0.5);
#	    } else {
#		$yv= int($v*15/5000 + 0.5);
#	    }
	    

	    $yv= 15 if $yv>15;
	    #	    $yv= 0 if $yv<0;
	    #	    $yv= 6 if $yv<0;
	    $yv= 6 if $yv<6;

#	    $yv= 15;
	    
	    print "  $v\t${v}v\t$yv\t${f}hz\t$p\t$hi\t$lo\n";

	    $bytes[$n*2 + 0]= $lo;
	    $bytes[$n*2 + 1]= $hi;
	    $bytes[8 + $n]  = $yv;

	    # mixer set bit 0
	    if (!$noise) {
		$mixer ^= (1<<(3-$n));
	    }
	    
	    # only have 3 osc
	    last if !--$n;
	}

	$bytes[7]= $mixer;

	if ($got) {
	    push @frames, [ @bytes ];


	    if ($opts{'f'}) {
		# TODO: currently the .f samples are too sparse - 4x slower!
		push @frames, [ @bytes ];
		push @frames, [ @bytes ];
		push @frames, [ @bytes ];
	    }
	}

    }
}
close($in_fh) unless $input_path eq '-';

# 3. Write Output
my $num_frames = scalar @frames;
die "Error: No AY data found!\n" if $num_frames == 0;

open(my $out_fh, '>', $output_path) or die "Error: Cannot open output '$output_path': $!\n";
binmode($out_fh);

print $out_fh "YM3!";
for my $reg_idx (0..13) {
    for my $f_idx (0..$num_frames - 1) {
        print $out_fh pack('C', $frames[$f_idx][$reg_idx]);
    }
}
close($out_fh);

print "Done! Processed $num_frames frames into $output_path\n";

sub usage {
    print "Usage: perl $0 [-r] <input_file> <output_file>\n";
    print "  <input_file>  Use '-' for STDIN\n";
    print "  -r            Raw mode (input is binary 14-byte repeated chunks)\n";
    exit 1;
}
