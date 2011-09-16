#!/usr/bin/perl -w
# $Id: varnish_stats.pl,v 1.6 2011/09/16 07:48:05 ivdmeer Exp $
#
# For docs see PODS or use Perldoc 
#
use strict;
use Getopt::Long;
use Net::Telnet ();
use Pod::Usage;



#####################
# Do not edit below #
#####################

# Get options else use defined options at config part
my $opt_category = 'all';
my $opt_help = 0;
my $opt_host = '127.0.0.1'; # default host
my $opt_port = '30000';     # default port number

GetOptions(
	'category|c=s'   => \$opt_category,
	'hostname|h=s'   => \$opt_host,
	'port|p=i'   => \$opt_port,
	'help|?' => \$opt_help 
) or pod2usage(2);
pod2usage(1) if $opt_help;


# flush after every write
#$| = 1;







###
# Description: Opens a telnet connection to given $host and $port
# Param: host, port (scalars)
# Returns: arrayref
###
sub fetch_varnishstats {
	my $host = shift;
	my $port = shift;
	my $rawdata = [];

	my $t=new Net::Telnet( Timeout => 10,
		Host=>$host,
		Port=>$port,
		Binmode=>0,
		Prompt=>'//'
	);

	$t->open() || die "Can't open connection!" ;
	$t->put(String=>"\n");
	$rawdata=$t->get();
	$t->close();
	return $rawdata;
}







###
# Description: Processes a list strings containing varnish stats 
#  and creates a hash with key value pairs
# Param: arrayref
# Returns: hashref
###
sub process_varnishstats {
	my $rawdata = shift;
	my ($desc, $val);
	my $data = {};

	# process data
	my @lines=split /\n/,$rawdata;
	foreach my $line (@lines) {
		# validate if given line has a value and a description if not skip it
		if ($line !~ /^[\s]+([\d]+)[\s]+(.*)$/) { 
			next;
		}

		# If no description found skip it
		unless (defined($2) && length($2) > 0) {
			next;
		}
		
		# If value found use it or if  no value found initialise with 0 
		$val = (defined($1) && length($1) > 0) ? $1 : 0; 

		# Set and uniform description
		$desc = $2;
		$desc=~s/ /_/g;
		$desc=~s/\.//g;
		$desc=~s/[()]//g;
		$desc=lc($desc);

		$data->{"$desc"} = $val;
	}

	# calculate hit rate
	$data->{'cache_hitrate'} = (exists($data->{'cache_hits'}) && exists($data->{'cache_misses'})) ? 
		int($data->{'cache_hits'} / ($data->{'cache_hits'} + $data->{'cache_misses'}) * 100) : 0; 
	
	return $data;
}







###
# Description: Return a arrayref of varnishstats items for given category
# Param: category 
# Returns: arrayref | undef
###
sub get_varnishstats_items_by_category {
	my $category = shift;
	unless (defined($category) && ref(\$category) eq 'SCALAR' && $category ne 'all') {
		return undef;
	}

	# Available varnishstats at varnish v 2.1.5 with a few custom items
	#  e.g. cache_hitrate
	# 
	# allocator_requests backend_conn_recycles backend_conn_reuses 
	# backend_conn_success backend_conn_was_closed backend_requests_made 
	# bytes_allocated bytes_free cache_hitrate cache_hits cache_misses 
	# client_connections_accepted client_requests_received client_uptime 
	# fetch_chunked fetch_with_length hcb_inserts hcb_lookups_with_lock 
	# hcb_lookups_without_lock n_backends n_expired_objects n_large_free_smf 
	# n_lru_moved_objects n_new_purges_added n_small_free_smf n_struct_object 
	# n_struct_objectcore n_struct_objecthead n_struct_sess_mem n_struct_smf 
	# n_struct_vbe_conn n_total_active_purges n_vcl_available n_vcl_total 
	# n_worker_threads n_worker_threads_created n_worker_threads_limited 
	# objects_sent_with_write outstanding_allocations session_closed session_herd 
	# session_linger session_pipeline shm_flushes_due_to_overflow shm_records 
	# shm_writes total_body_bytes total_fetch total_header_bytes total_pass 
	# total_requests total_sessions

	# Defining varnishstats categories
	my %defs = ( 
		'backend_stats' => { 
				map { $_ => undef} 
					qw/
						backend_conn_reuses
						backend_conn_success
						backend_conn_was_closed
						backend_requests_made
						backend_conn_recycles
					/
		},
		'cache_stats' => {
				map { $_ => undef} 
					qw/
						cache_hits
						cache_hitrate
						cache_misses
						client_connections_accepted
						client_requests_received
					/
		},
		'client_stats' => {
				map { $_ => undef} 
					qw/
						client_connections_accepted
						client_requests_received
					/
		},
		'mem_stats' => {
				map { $_ => undef} 
					qw/
						bytes_allocated
						bytes_free
					/
		},
		'total_stats' => {
				map { $_ => undef} 
					qw/
						total_fetch
						total_pass
						total_requests
						total_sessions
					/
		},
	);

	unless (exists($defs{$category})) {
		die('Unsupported varnishstats category, supporting the following categories: all, ' . join (', ', keys(%defs)));
	}
		
	my @output = keys(%{$defs{$category}});
	return \@output;
}







###
# Description: print a cacti compliant string of all varnishstats or optional given keys
# Param: data aka varnishstats (hashref), options (arrayref)
# Returns: void
###
sub print_varnishstats {
	my $data = shift;
	my $options = shift;
	unless (defined($data) && ref($data) eq 'HASH') {
		die("First argument must be a hashref!\n");
	}
	unless (defined($options) && ref($options) eq 'ARRAY') {
		my @options = keys(%$data);
		$options = \@options;
	}
	
	print sprintf("%s\n", 
		join(' ', 
			map { (exists($data->{$_}) && length($data->{$_}) > 0) ? sprintf("%s:%s", ucfirst($_), $data->{$_}) : next; } @$options
		)
	); 
}







my ($data, $rawdata);
$rawdata = fetch_varnishstats($opt_host, $opt_port);
$data = process_varnishstats($rawdata);
print_varnishstats($data, get_varnishstats_items_by_category($opt_category));






__END__


=head1 NAME

varnish_stats.pl - varnish stats cacti script

=head1 DESCRIPTION

Simple script to query xinetd which collects the Varnish statistics and generates a formatted string for use at Cacti.

=head1 SYNOPSIS

varnish_stats.pl [options]

    Options:
        -c or --category
        -h or --hostname
        -p or --port

    If no options are specified, script will failback to default settings
    configured at config part of this script

=head1 DOCUMENTATION

=head2 xinetd service file:

=over 4

=back

  service varnishstat
  {
        protocol    = tcp
        wait        = no
        port        = 30000
        bind        = 1.1.1.1
        only_from   = 1.1.1.1
        user        = root
        server      = /usr/bin/varnishadm
        server_args = -S /etc/varnish/secret -T 127.0.0.1:6082 stats
  }


  Change port, bind and only_from to your needs (tested on Debian 6.0.2)

=head2 output:

=over 4

=back

 Cache_hits:280 Backend_requests_made:278 Cache_misses:193 ..... 

=head1 AUTHORS

Ivdmeer

=cut



