#! /usr/bin/env perl
use Getopt::Long;

#default values
$match='';
@line=();
$delim=' ';

GetOptions("match=s"=>\$match,
           "delimiter=s"=>\$delim,
	   "strip=s"=>\$strip,
           "help"=>\$help
	);

if($help) { &usage() }
while(<STDIN>) {
unless (/^$match$/) {
	chomp($_);
	if($strip) {@tmp = split(/$strip/,$_); $curline=$tmp[1];} else {$curline = $_};
	push(@line,$curline); }
if($_ =~ /^$match$/ || eof) {
	print join($delim,@line),"\n";
	@line=();
}
}

sub usage {
print <<EOF;
ml [--match] [--delimiter] [--strip] [--help]
This program reads from the STDIN and merges multiple lines into one line splitting the input on the user supplied string
--match		the string to match to split the input. default is an empty line
--delimiter	the delimiter to use between fields. default is a space
--strip		optionally if the input lines contain field names you can supply the delimiter so they can be stripped. defaults to no stripping
EOF
exit 1;
}
