#!/usr/bin/perl
use Net::LDAP;
use IP::Country::Fast;
use DBI;
use SOAP::Lite +trace => [ result => parameters ];
use Data::Dumper;
use List::MoreUtils qw(uniq);
use Getopt::Long;
#use strict;
use Sys::Syslog;
use Env;

my ( %opt, %daydata, %sessionentry ) = ();
my ( $proxy, $soapresponse, $daydata, $totals, $key, $j, $entry, $uid, @row, $clients, @clients, $client, @unique_countries, $comment );
my @sessions;
my @params;
my $verbose = 0;

my $ldap = Net::LDAP->new ( $ENV{LDAP_SERVER} ) or die "$@";
my $mesg = $ldap->bind ();
my @countries = ();

sub finduid {
  my ($mail) = @_;
  my $result = $ldap->search(base => $ENV{LDAP_BASE}, filter => "(|(mail=$mail)(mailalternateaddress=$mail))", attrs => ['uid']);
  my @entries = $result->entries;
  foreach $entry ( @entries ) {
        $uid = $entry->get_value('uid');
  }
 return $uid;
}

sub DEBUG {
  my ($msg,$level) = @_;
  if($verbose >= $level) { print $msg, "\n"; }
}

GetOptions ('verbose+' => \$verbose);

openlog("sasl_watch", "ndelay,pid", LOG_LOCAL0);
my $reg = IP::Country::Fast->new();
$proxy = 'https://observer.otenet.gr/blacklist/pages/saslsoap.php';
my $dbh = DBI->connect("dbi:mysql:syslog:$ENV{SYSLOG_DB_SERVER}", $ENV{SYSLOG_DB_USER}, $ENV{SYSLOG_DB_PASS});
my $dbhb = DBI->connect("dbi:mysql:mail-blacklist:$ENV{BLACKLIST_DB_SERVER}",$ENV{BLACKLIST_DB_USER},$ENV{BLACKLIST_DB_PASS});
my @bind_values = ();
my $sth = $dbh->prepare("select trim(leading 'sasl_username=' from username) as username,group_concat(DISTINCT trim(leading 'client=' from client) SEPARATOR '') as ip_list, count(distinct(client)) as num from sasl where client NOT REGEXP 'otenet.gr|google.com|cosmote.gr|cosmote.net|hol.gr|forthnet.gr|unknown\\\\[10\\\\.' group by username having num>5 order by num asc");
$sth->execute(@bind_values);
if($sth->rows == 0) { DEBUG("no usernames found",2); exit 0;} else { DEBUG($sth->rows." usernames found",2); }
do {
    while (@row= $sth->fetchrow_array())  {
	DEBUG("parsing $row[0]...",1);
	@countries=();
	@unique_countries=();
	chop($row[1]);
	@clients=split(',',$row[1]);
	foreach $client ( @clients ) {
		my ($hostname,$ip)=split('\[',$client);
		chop($ip);
		push(@countries,$reg->inet_atocc($ip));
	}
	my @unique_countries = uniq @countries;
	if( (scalar @unique_countries == 1) && ($unique_countries[0]=='GR')) {DEBUG("IPs only in greece, won't block",2); next; }
	$comment = sprintf("%s different IPs in %s countries (%s): %s",$row[2],scalar @unique_countries,join(',',@unique_countries),join(', ',@clients));
	my $blocked = $dbhb->prepare("SELECT * FROM blacklisted WHERE uid LIKE ?");
	$blocked->execute(&finduid($row[0]));
	if($blocked->rows gt 0) { 
				DEBUG("User already blocked, won't block again",2);
				syslog(LOG_INFO,$row[0].", ".&finduid($row[0]).", already blocked by sasl_watch, found again with: ".$comment);
				next; 
				}
	DEBUG("calling SOAP::Lite -> service('http://observer.otenet.gr/blacklist/pages/saslsoap.php?wsdl') -> lookup($row[0],&finduid($row[0]),'Blocked by sasl_watch: '.$comment)",3);
	syslog(LOG_INFO,$row[0].", ".&finduid($row[0]).", ".$comment);
	print SOAP::Lite -> service('https://observer.otenet.gr/blacklist/pages/saslsoap.php?wsdl') -> lookup(&finduid($row[0]),$row[0],"Blocked by sasl_watch: $comment") . "\n";
    }
  } until (!$sth->more_results);
closelog();
