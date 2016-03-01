#!/usr/bin/perl -w

my @word = ();
my @lines = ();
my $depth = 0;
my $is_used = 0;
my @orig = ();
my (%simple, %array);
my %keyword=(for=>1, if=>1, else=>1, while=>1, print=>1, push=>1);
open(IN,"<$ARGV[0]") || die ("Could not open file");
foreach my $line1 (<IN>) {
	chomp $line1;
	if ($line1 =~ /\/usr\/bin\/python/) {
		$line1 =~ s/python/perl -w/;
		print "$line1\n";
		next;
	}
	if ($line1 =~ /^import .*$/) {next;}
	if ($line1 =~ /^\s+break$/) {$line1 =~ s/break/last/;}
	if ($line1 =~ /^\s+continue$/) {$line1 =~ s/continue/next/;}
	if ($line1 =~ /^\s*elif .*$/) {$line1 =~ s/elif/elsif/;}
	if ($line1 =~ /^\s*([_a-zA-Z][0-9_a-zA-Z]*)\s*=[^\[]*/) {$simple{$1} = 1;}
	if ($line1 =~ /^\s*for ([_a-zA-Z][0-9_a-zA-Z]*).*/) {$simple{$1} = 1;}
	if ($line1 =~ /^\s*([_a-zA-Z][0-9_a-zA-Z]*)\s*= \[\]$/) {$array{$1} = 1; next;}
	if ($line1 =~ /(sys[.]stdout.*)\(/) {
		$line1 =~ s/$1/write/;
		$line1 =~ s/\(/ /;
		$line1 =~ s/\)//;
	}

	if ($line1 =~ / (int)\(/) {$line1 =~ s/$1//;}
	
	if ($line1 =~ /\(*sys.stdin.readline\(\).*/) {$line1 =~ s//<STDIN>/;}
	if ($line1 =~ /^\s*([_a-zA-Z][0-9_a-zA-Z]*) = (sys.stdin.readlines\(\).*)/) {
		my $a = $1;
		my $b = "@".$a;
		$line1 =~ s/\Q$2\E/<STDIN>/;
		$line1 =~ s/(\Q$a\E)/$b/;
		$array{$a} = 1;
		next;
	}
	if ($line1 =~ /^(\s*)([a-zA-Z0-9_]+)\.append\((.*)\)$/) {$line1 = $1."push ".$2." , ".$3;}
	if ($line1 =~ /^\s*for [^ ]+ in range.*/) {
		$line1 =~ s/for/foreach/;
		$line1 =~ s/in range//;
	}
	if ($line1 =~ /^\s*for [^ ]+ in sys.stdin.*$/) {
		$line1 =~ s/for/foreach/;
		$line1 =~ s/in //;
		$line1 =~ s/sys.stdin/(<STDIN>)/;
		$is_used = 1;
	}
	if ($line1 =~ /(\/)/ || $line1 =~ /(\+)/ || $line1 =~ /(-)/ || $line1 =~ /(\*)/) {
		if ($line1 !~ /\s*write/) {
			$line1 =~ s// $1 /;
		}
	}
	if ($line1 =~ /^(\s*)([_a-zA-Z][0-9_a-zA-Z]*)\s*=\slen\(.+\).*$/) {
		if ($is_used == 0) {
			push @orig, $1.$2." = 0";
			push @orig, $1."while"." <STDIN>:";
			push @orig, $1."    ".$2." ++";
			next;
		}
		else {
			$line1 =~ s/len//;
			$line1 =~ s/[\(\)]//g;
			push @orig, $line1;
			$is_used = 0;
			next;
		}
	}
	if ($line1 =~ /^\s*print.*,$/) {
		$line1 =~ s/print/output/;
		$line1 =~ s/,$//;
	}
	if ($line1 =~ /^(\s*)print \"(.*)\" % (.*)$/) {
		my $sp = $1;
		my $str = $2;
		my $var = '$'.$3;
		$str =~ s/%\d*[dfs]/$var/g;
		push @orig, $sp."print ".'"'.$str.'"';
		next;
	}
	if ($line1 =~ /(.*:) (.*)/ && $line1 !~ /\s*write/) {
		push @orig, $1;
		my $temp = $2;
		if ($temp =~ /;/) {
			my @tmp = split (/; /, $temp);
			foreach my $i (@tmp) {push @orig, "    ".$i;}
		}
		else {push @orig, "    ".$temp;}
		next;
	}
	push @orig, $line1;
}

foreach my $line (@orig) {
	my $count = 0;
	if ($line =~ /^ *$/) {next;}
	if ($line =~ /(^ +).*/) {
		my $tmp = $1;
		while ($tmp =~ / /g) {
			$count++;
		}
		$count /= 4;
		if ($count >= $depth) {
			$depth = $count;
		}
		else {
			my $gap = $depth - $count;
			&closePrint($gap,$depth);
			$depth = $count;
		}
		&process($line);
		next;
	}
	if ($line =~ /^[^ ].*$/) {
		if ($depth > 0) {
			&closePrint($depth,$depth);
			$depth = 0;
		}
		&process($line);
		next;
	}
	&process($line);
}
if ($depth != 0) {&closePrint($depth,$depth);}

sub process {
	my ($line) = @_;
	my @word = ();
	if ($line =~ /^\s*#.*$/) {
		print "$line\n";
		return;
	}
	if ($line =~/^(.* )([a-zA-Z_][a-zA-Z0-9_]*)\[([a-zA-Z_][a-zA-Z0-9_]*)\](.*)$/) {
		my $f = $1;
		my $l = $4;
		my $m = '$'.$2;
		my $n = $3;
		if (&checkType($n) == 2) {$n = '$'.$n;}
		$line = join ("", $f,$m,'[',$n,']',$l);
	}
	if ($line =~ /:$/) {$line =~ s/:/ \{/;}
	if ($line !~ /^\s*write.*/) {
		my @ar = split (/ /, $line);
		foreach $j (@ar) {
			if (&command($j)) {
				if (&checkType($j) == 1) {$j = "@".$j;}
				elsif (&checkType($j) == 2) {$j = "\$".$j;}
			}
			$line = join (" ", @ar[0..$#ar]);
		}
	}	
	if ($line =~ / *if (.*) \{$/ || $line =~ / *while (.*) \{$/) {
		my $w = $1;
		$line =~ s/(\Q$w\E)/($1)/;
	}
	if ($line =~ / *foreach .* \{$/) {
		if ($line =~ /, (\d+)/) {
			my $o = $1;
			my $t = $o - 1;
			$line =~ s/$o/$t/;
			$line =~ s/, /../;
		}
		elsif ($line =~ /, \$[_a-zA-Z][0-9_a-zA-Z]*( \+ 1)/) {
			$line =~ s/\Q$1\E//;
			$line =~ s/, /../;
		}
	}
        if ($line =~ /^\s*print.+$/) {
                $line = join (", ", $line, '"\n"');
	}
	if ($line =~ /^\s*print$/) {$line = "print".' "\n"';}
	if ($line =~ / *(write)/) {$line =~ s/\Q$1\E/print/;}
	if ($line =~ / *(output)/) {$line =~ s/\Q$1\E/print/;}
	$line = &addSemic($line);
	print "$line\n";
}

sub closePrint {
	my ($gap, $depth) = @_;
	for (my $i = 0; $i < $gap; $i++) {
		for (my $j = 0; $j < $depth - 1; $j++) {
			print "    ";
		}
		print "}\n";
		$depth--;
	}
}

sub checkType {
	my ($w) = @_;
	foreach my $k1 (keys %array) {if ($w eq $k1) {return 1;}}
	foreach my $k2 (keys %simple) {if ($w eq $k2) {return 2;}}
}

sub addSemic {
	my ($l) = @_;
	if ($l !~ /if/ && $l !~ /else/ && $l !~ /while/ && $l !~ /foreach/){return join("",$l,";");}
	else {return $l;}
}

sub command{
	my ($w) = @_;
	if ($w ne "in" && $w ne "print" && $w ne "if" && $w ne "else" && $w ne "while" && $w ne "foreach"){return 1;}
	else {return 0;}
}
