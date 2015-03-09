#! /usr/bin/env perl
use Getopt::Long;

#default values
$match='|';
@line=();
$delim="\n";

GetOptions("match=s"=>\$match,
           "delimiter=s"=>\$match,
	   "strip"=>\$strip,
           "help"=>\$help
	);

if($help) { &usage() }
if($match eq '|') { $match='\|'; }
while(<STDIN>) {
	@tmp = split(/$match/,$_);
	if($strip) {
		foreach $tmp ( @tmp ) {
			$tmp =~ s/^\s+|\s+$//g;
			push(@clean,$tmp);
		}
		print join($delim,@clean),"\n\n";
		undef @clean;
	}
	else {		 
	print join($delim,@tmp),"\n";
	undef @tmp;
	}
}

sub usage {
print <<EOF;
sl [--match] [--delimiter] [--strip] [--help]
This program reads from the STDIN and splits lines into multiple lines splitting the input on the user supplied string
--match|--delimiter	the string to match to split the input. Default is |
--strip			strip lines from preceding and trailing blanks
EOF
exit 1;
}
