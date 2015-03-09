#!/bin/env perl
use Net::LDAP;
use Getopt::Long qw(:config no_ignore_case);
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Term::ReadKey;
use lib '/usr/local/bin/';
use My::Config qw(ldapconfig ldapbaseconfig);
$base = &ldapbaseconfig;
sub usage() {
print <<EOF;
ldapsearch.pl [--base base] [--ou ou] [--host hostname] [--port] [--proto|P protocol version] [--scope scope] [--values|--names] [--strict] [--table] [--delimiter] [--csv] [-D username] [-w password] [-W] [--count] [--append text] [-H] [--date] [--nocolor] [--noblanks|-l] filter [attribute list]

Antikatastatis tou ldapsearch se perl me merikes beltioseis pano sto
prototypo.
An do8ei lista me attributes meta to filtro typonei MONO afta ta
attributes xoris na typonei mazi kai to dn, ektos an einai kai 
afto mesa stin lista.
Diaforetika typonei ola ta attributes.
Stin periptosi pou kapio attribute exei ellinika i teleionei se space
den ta kanei base64 alla ta typonei bold kai kokkina gia na 3exorizoun.

--base		set base
--ou		set ou, $base is appended by default
--host		set host
--port		set port if different than 389
--proto|P	set protocol version if different than 3
--scope		set scope
--values	print only values without attribute names
--names		print only values without attribute names
--strict	print all attributes even if they don't exist in a record (in that case it displays NULL)
--table		print output in table format
--delimiter	delimiter to use when printing in table format (default tab)
--csv		shortcut to set output to table, set strict on and the delimiter to ,
-D		username to use for bind
-w		password to use for bind
-W		enter password interactively to use for bind
--count		display number of results.
--append	text to append after the dn. Can accept multiple values
-H		display hidden attributes (creatorsName, createTimestamp, modifiersName, modifyTimestamp)
--date		convert days since epoch to datetime
--color		don't colorize invalid values (i.e nonASCII, etc)
--noblanks|-l	don't print blank lines between results

EOF
exit 0;
}
$color=0;

GetOptions( \%opt,
        'base=s',
	'ou=s',
        'host=s',
        'scope=s',
	'values|names',
	'strict',
	'table',
	'delimiter=s',
	'csv',
	'D=s',
	'w=s',
	'W',
	'count',
	'append=s@',
	'x',
	'port=s',
	'proto|P=s',
	'H',
	'date',
	'color',
	'noblanks|l',
	'schema',
	'iproute32'
);
if ( ! @ARGV && ! %opt ) { &usage() };
if ( !$opt{'host'} ) { print "You forgot to specify a host to connect to!\n"; &usage() };
if( $opt{'base'} ) { $base=$opt{'base'}; } elsif( $opt{'ou'} ) { $base='ou='.$opt{'ou'}.','.&ldapbaseconfig;} else { $base=&ldapbaseconfig;}
if( $opt{'host'} ) { $host=$opt{'host'}; }
if( $opt{'port'} ) { $port=$opt{'port'} } else { $port=389; }
if (index($host, ':') == -1) { $host=$host.":".$port; }
if( $opt{'scope'} ) { $scope=$opt{'scope'}; } else { $scope='sub';}
if( $opt{'values'} ) { $values=1;}
if( $opt{'color'} ) { $color=1;}
my ($username,$password) = ldapconfig($host);
if( $opt{'D'} ) { $username=$opt{'D'}; }
if( $opt{'w'} ) { $password=$opt{'w'}; }
if( $opt{'W'} ) { print "Enter LDAP password: "; $|=1; ReadMode('noecho'); $password=<STDIN>; chomp $password; ReadMode(0); print "\n";}
if( $opt{'append'} ) { @append=@{$opt{'append'}}; }
$delim = $opt{'delimiter'} ? $opt{'delimiter'} : "\x9";
if( $opt{'csv'} ) { $opt{'table'}=1; $opt{'strict'}=1; $delim=","; }
$proto = $opt{'proto'} ? $opt{'proto'} : 3;

$filter=$ARGV[0];
shift @ARGV;
$ldap = Net::LDAP->new ( $host ) or die "$@";
$mesg = $ldap->bind ( $username, password => "$password", version => $proto );
$argc = scalar @ARGV;
$show_dn=1;
if($argc > 0) {
unless(grep(/^dn$/, @ARGV)) { $show_dn=0; }
}

if($opt{'schema'} && $filter =~ m/objectClass=/i) {
$schema = $ldap->schema ( );
print "searching for ", $filter, "\n\n";
my ($attr,$fltr) = split('=',$filter);
if($fltr ne '*') {
$res = $schema->objectclass( $fltr );
foreach $attr ( keys %$res) {
	if(ref($$res{$attr}) eq 'ARRAY') { print $attr, ": ", "@{$$res{$attr}}", " \n"; }
	else { print "$attr:  $$res{$attr}", "\n"; }
	}
}
else {
@classes = $schema->all_objectclasses ( );
 foreach $ar ( @classes ) {
   print "ObjectClass: ", $ar->{name}, "\n";
   foreach $key ( keys %{$ar} ) {
	if(ref($ar->{$key}) eq 'ARRAY') { print $key, ": ", "@{$ar->{$key}}", " \n"; }
	else { print "$key:  $ar->{$key}", "\n"; }
   }
   print "\n\n";
 }
}
$ldap->unbind;
exit 0;}


if($opt{'schema'} && $filter =~ m/attribute=/i) {
$schema = $ldap->schema ( );
print "searching for ", $filter, "\n\n";
my ($attr,$fltr) = split('=',$filter);
if($fltr ne '*') {
$res = $schema->attribute( $fltr );
foreach $attr ( keys %$res) {
        if(ref($$res{$attr}) eq 'ARRAY') { print $attr, ": ", "@{$$res{$attr}}", " \n"; }
        else { print "$attr:  $$res{$attr}", "\n"; }
        }
}

$ldap->unbind;

exit 0; }

if(@ARGV) { @attrs = @ARGV; } else { @attrs = qw(*); }
if($opt{'H'}) { @exattrs = qw(creatorsname createtimestamp modifiersname modifytimestamp pwdChangedTime pwdPolicySubentry pwdFailureTime pwdAccountLockedTime); push(@attrs, @exattrs); }
if($opt{'iproute32'}) { @ipattrs = qw(ciscoAVPairs); push(@attrs, @ipattrs); }
my $result = $ldap->search(base => $base, filter => $filter, scope => $scope, attrs => \@attrs);

my @entries = $result->entries;
if($opt{'table'}) {
print join($delim, @ARGV), "\n" unless $values;
my $entr;
 foreach $entr ( @entries ) {
   my $attr;
   if($opt{'strict'}) {
   foreach $attr ( @attrs ) {
     next if ( $attr =~ /;binary$/ );
     $val = $entr->get_value ($attr) ? $entr->get_value ($attr) : "NULL";
     printf "%s%s",$val,$delim;
     }
   }
   elsif($opt{'iproute32'}) {
   foreach $attr ( $entr->attributes ) {
     next if ( $attr =~ /;binary$/ );
     foreach $val ( $entr->get_value ($attr) ) {
       $val =~ tr/ //s;
       if($val =~ m/ip:route.*255\.255\.255\.255$/) {
	printf "%s%s",(split(/ /,$val))[2],$delim;
       }
       elsif($attr !~ m/cisco/i) { printf "%s%s",$val,$delim; }
     }
   }
   }
   else {
   foreach $attr ( $entr->attributes ) {
     next if ( $attr =~ /;binary$/ );
     foreach $val ( $entr->get_value ($attr) ) {
       printf "%s%s",$val,$delim;
     }
   }
   }
print "\n"; 
}
}
else {
 my $entr;
 foreach $entr ( @entries ) {
   if($show_dn==1) { if($values) { print $entr->dn, "\n"; } else { print "dn: ", $entr->dn, "\n"; } }
   if( @append ) { foreach $line ( @append ) { print $line, "\n"; } print "\n" if $argc==1; }

   my $attr;
   if($opt{'strict'}) {
   foreach $attr ( @attrs ) {
     # skip binary we can't handle
     next if ( $attr =~ /;binary$/ );
     $val = $entr->get_value ($attr) ? $entr->get_value ($attr) : "NULL";
	unless($values) { print "$attr: "; } print $val, "\n";
	}
   }
   else {
   foreach $attr ( $entr->attributes ) {
     # skip binary we can't handle
     next if ( $attr =~ /;binary$/ );
     foreach $val ( $entr->get_value ($attr) ) {
	#convert days since epoch to datetime for specific attributes
	if($attr =~ /shadowLastChange|shadowExpire|pageExpire|mailExpire/i && $opt{'date'}) {$val = $val." (".localtime(86400*$val).")"; }
	#gia ka8e attribute tsekaroume an exei non-ascii xaraktires i an teleionei se space kai an nai to typonoume bold kai kokkino
	if((($val =~ /[^\x00-\x7F]/) || ($val =~ / $/)) && $color) { unless($values) { print BOLD RED "$attr: "; } print BOLD RED $val, "\n"; }
	else { unless($values) { print "$attr: "; } print $val, "\n"; }
	}
   }
   }

   unless ((@ARGV && $filter =~ m/\*/) || $opt{'noblanks'}) { print "\n"; }
 }
}
if($opt{'count'}) { print "Number of results: ", scalar @entries, "\n"; }

$ldap->unbind;
