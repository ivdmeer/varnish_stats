#!/usr/bin/perl -w
# Id: varnish_stats.pl,v 1.2 2011/09/01 13:02:24 ivdmeer Exp
#
# Simple script to query xinetd which collects the Varnish statistics 
#  and generates a formatted string for use at Cacti. 
#
# Author: Ivo van der Meer (ivdmeer)
#
# Example xinetd service
#
#  service varnishstat
#  {
#        protocol    = tcp
#        wait        = no
#        port        = 30000
#        bind        = 1.1.1.1
#        only_from   = 1.1.1.1
#        user        = root
#        server      = /usr/bin/varnishadm
#        server_args = -S /etc/varnish/secret -T 127.0.0.1:6082 stats
#  }
#

use strict;
use Net::Telnet ();

# flush after every write
$| = 1;


my $host=shift || '127.0.0.1';	# default host
my $port=shift || 30000;	# default port number

my $t=new Net::Telnet( Timeout => 10,
	Host=>$host,
	Port=>$port,
	Binmode=>0,
	Prompt=>'//'
);
$t->open() || die "Can't open connection!" ;
$t->put(String=>"\n");
my $l=$t->get();
$t->close();


my ($val, $desc);

# process data
my @lines=split /\n/,$l;
foreach my $line (@lines) {
	# validate if given line has a value and a description if not skip it
	if ($line !~ /^[\s]+([\d]+)[\s]+(.*)$/) { 
		next;
	}

	unless (defined($1) && defined($2) && length($1) >1 && length($2) >1) {
		next;
	}

	# use value and description
	$val = $1;
	$desc = $2;

	# reformat description
	$desc=~s/ /_/g;
	$desc=~s/\.//g;
	$desc=~s/[()]//g;
	$desc=lc($desc);
	print sprintf("%s:%s ", $desc, $val);
}

print "\n";

