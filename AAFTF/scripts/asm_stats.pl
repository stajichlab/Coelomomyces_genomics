#!/usr/bin/perl
#
use File::Spec;
use strict;
use warnings;

my %stats;

my $readlen = 150; # assume reads are 150bp?

my $read_map_stat = 'mapping_report';
my $dir = shift || 'genomes';
my %cols;
my @header;
my %header_seen;

opendir(DIR,$dir) || die $!;
my $first = 1;
foreach my $file ( readdir(DIR) ) {
    next unless ( $file =~ /(\S+)\.stats.txt$/);
    my $stem = $1;
    $stem =~ s/\.sorted//;
    $stem =~ s/DNA//;
    open(my $fh => "$dir/$file") || die $!;
    while(<$fh>) {
	next if /^\s+$/;
	s/^\s+//;
	chomp;
	if ( /(.+)\s+=\s+(\d+(\.\d+)?)/ ) {
	    $stats{$stem}->{$1} = $2;
#      warn($1," ", $2,"\n");
	    $cols{$1}++;
	    if( ! exists $header_seen{$1} ) {
		push @header, $1;
		$header_seen{$1} = 1;
	    }
	}
    }

    if ( $first ) { 
	push @header, qw(BUSCO_Complete BUSCO_Single BUSCO_Single BUSCO_Single
                 BUSCO_Fragmented BUSCO_Missing BUSCO_NumGenes
                 );
    }


    my $busco_file = File::Spec->catfile("BUSCO",sprintf("run_%s",$stem),
					 sprintf("short_summary_%s.txt",$stem));

    if ( -f $busco_file ) {

	open(my $fh => $busco_file) || die $!;
	while(<$fh>) {	 
	    if (/^\s+C:(\d+\.\d+)\%\[S:(\d+\.\d+)%,D:(\d+\.\d+)%\],F:(\d+\.\d+)%,M:(\d+\.\d+)%,n:(\d+)/ ) {
		$stats{$stem}->{"BUSCO_Complete"} = $1;
		$stats{$stem}->{"BUSCO_Single"} = $2;
		$stats{$stem}->{"BUSCO_Duplicate"} = $3;
		$stats{$stem}->{"BUSCO_Fragmented"} = $4;
		$stats{$stem}->{"BUSCO_Missing"} = $5;
		$stats{$stem}->{"BUSCO_NumGenes"} = $6;
	    } 
	}

    } else {
	warn("Cannot find $busco_file");
    }
	
    my $sumstatfile = File::Spec->catfile($read_map_stat,
				      sprintf("%s.bbmap_summary.txt",$stem));
    if ( -f $sumstatfile ) {
	open(my $fh => $sumstatfile) || die "Cannot open $sumstatfile: $!";
	while(<$fh>) {
	    if( /Scaffold statistics.+\s+(\S+)$/) {
		my $filename = $1;
		my (undef,$pth,$nm) = File::Spec->splitpath($filename);
		my ($inbase) = split(/\.bbmap/,$nm);
		if( $inbase ne $stem) {
		    warn("$inbase for $nm not matching $stem\n");
		    exit;
		}		
	    } elsif( /^(Reads|Mapped reads|Average coverage):\s+((\d+\.)?\d+)/ ){
		unless( exists $header_seen{$1} ) {
		    $header_seen{$1} = 1;
		    push @header, $1;
		}
		$stats{$stem}->{$1} = $2;
	    }
	}
    }
#    my $mapstat = File::Spec->catfile($read_map_stat,
#				      sprintf("%s.bbmap_covstats.txt",$stem));
#    if ( -f $mapstat ) {
#	open(my $fh => $mapstat) || die "cannot open $mapstat: $!";
#	my ($chromlen,$readcount) = (0,0);
#	while (<$fh>) {
#	    next if /^\#/;
#	    my @row = split;
#	    $chromlen += $row[2];
#	    $readcount += $row[6] + $row[7];
#	}
#	$stats{$stem}->{'Fold_cov'} = sprintf("%.2f",
#					      $readlen * $readcount / 
#					      $chromlen);
#    }    

    $first = 0;
}

print join("\t", qw(SampleID), @header), "\n";
foreach my $sp ( sort keys %stats ) {    
    print join("\t", $sp, map { $stats{$sp}->{$_} || 'NA' } @header), "\n";
}
