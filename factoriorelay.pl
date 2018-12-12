#!/usr/bin/perl
use strict;
use IO::Socket;
use List::Util "sum";

# This script is used to replicate the Factorio LAN Game announcement packet across other subnets.
#
# Packet to replicate:
# 4500 001f a165 4000 ff11 9ae6 c0a8 de30
# c0a8 dfff caff 8594 000b db2c 0f95 8500
# 0000 0000 0000 0000 0000 0000 0000
#
# IP Header:  
# V: 4500 001f 	4 5 0 31	IPv4, header length of 5, 0 type of service, total length of 31
# I: a165 4000 	41317 010 000	ID 41317, Flag = 010b, Fragment Offset = 0
# T: ff11 9ae6 	255 17 39654	TTL = 255, Protocol 17 (UDP), Header Checksum = 39654
# S: c0a8 de30 	192168 222048	Source Address = 192.168.222.48
# D: c0a8 dfff 	192168 223255	Destination Addr = 192.168.223.255
#
# UDP Header:
# P: caff 8594 	51967 34196	Source Port: 51967, Destination Port: 34196
# L: 000b db2c	11 56108	Total Length: 11, UDP Checksum: 56108
#
# Data:		0f95 85		Represents the port to query for the Factorio Server in bit-reversed notation (34197 = 0x8595, 34198 = 0x8596)
#


# Config - Every subnet to announce to.  If an announcement is received from one
# of these subnets we will end up duplicating the announcement.
my @dest_list = ('192.168.220.63', '192.168.220.127', '192.168.220.191', '192.168.223.255');

# Define UDP Packet Header Fields
my $udp_src_port	= 51111;	# n - 16 bits - change if you need to chain relays together.
my $udp_dst_port	= 34196;	# n - 16 bits
my $udp_len		= 8;		# n - 16 bits - minimum is 8 which is the size of the header - calculated later
my $udp_cksum		= 0;		# n - 16 bits - calculated later

# Define IP Packet Header Fields
my $ip_ver		= 4;			# H ( 4 = IPv4 ) - 4 bits
my $ip_header_len	= 5;			# H ( 5 = 5 byte header length ) - 4 bits
my $ip_tos		= 00;			# H2 ( Type of Service) - 8 bits
my $ip_tot_len		= 20 + $udp_len;	# n ( total packet length - 16 bit unsigned integer) - 16 bits - calculated later
my $ip_frag_id		= 1337;			# n ( packet id ) - 16 bits
my $ip_frag_flag	= "010";		# B16.1 ( fragment flags - R DF MF ) - 3 bits
my $ip_frag_oset	= "0000000000000";	# B16.2 ( flags ) - 13 bits
my $ip_ttl		= 20;			# C ( Time to Live ) - 8 bits
my $ip_proto		= 17;			# C ( 17 = UDP ) - 8 bits
my $ip_cksum		= 0;			# n ( checksum ) - 16 bits - calculated by kernel
#my $ip_src_host = (gethostbyname($src_host))[4]; # a4 ( source IP in binary ) - 32 bits
#my $ip_dst_host = (gethostbyname($dst_host))[4]; # a4 ( destination IP in binary ) - 32 bits

# Setup receiving socket
my $recvsock = IO::Socket::INET->new(
	Proto => "udp",
	LocalPort => 34196
	) or die "Can't open listening UDP Port: $@";
my ($datagram, $flags);

# Run main loop
print "Starting main loop.\n";
while (1) {
	$recvsock->recv($datagram, 42, $flags);
	print "Received message from ",
		$recvsock->peerhost, ":", $recvsock->peerport,
		"  Flags: ", $flags || "none",
		"  Data: ", unpack('H*', $datagram),
		"\n";

	if ($recvsock->peerhost eq '127.0.0.1') {
		print "Ignoring localhost notification.\n\n";
		next;
	}

	if ($recvsock->peerport eq $udp_src_port) {
		print "Skipping over our own announcement packet to prevent a loop.\n\n";
		next;
	}

	# Build source dependent dynamic parts of the outbount packet
	my $ip_src_host = (gethostbyname($recvsock->peerhost))[4];
	my $udp_len     = 8 + length($datagram);
	my $ip_tot_len	= 20 + $udp_len;

	# Iterate over the destination subnet list
	foreach my $dst_host (@dest_list) {
		if (0 eq $dst_host) {
			# This doesn't work since I haven't figured out how to
			# extract the destination address of the received 
			# packet without using RAW sockets here too.  This 
			# means that if the source subnet is also in the 
			# destination list above, that the subnet will get two
			# packets.  Both will be correct but it's  wasteful of 
			# network resources.
			print "Skipping over sending broadcast to subnet we received from.\n";
			next;
		}

		print "Building notification for ", $dst_host, ":", $udp_dst_port, " from ", $recvsock->peerhost, ":", $udp_src_port, "\n";

		# Build destination dependent dynamic parts of the outbound UDP packet
		my $ip_dst_host = (gethostbyname($dst_host))[4];
		my ($udp_header) = pack('nnnn', $udp_src_port, $udp_dst_port, $udp_len, $udp_cksum);
		my ($udp_packet) = $udp_header . $datagram;
	
		# Calculate UDP Checksum
		my $udp_checksum = sum(
			$ip_proto,
			$udp_len,
			map({ unpack('n*', $_) }
				$ip_src_host,
				$ip_dst_host,
				$udp_packet . "\0"
			)
		);
		while (my $high = $udp_checksum >> 16) {
			$udp_checksum = ($udp_checksum & 0xFFFF) + $high;
		}
		$udp_checksum = ~$udp_checksum & 0xFFFF;
		substr($udp_packet, 6, 2, pack('n', $udp_checksum));

		# Build and Assemble IP Packet
		my ($ip_header) = pack('H2 H2 n n B16 C C n a4 a4', $ip_ver . $ip_header_len, $ip_tos, $ip_tot_len, $ip_frag_id, $ip_frag_flag . $ip_frag_oset, $ip_ttl, $ip_proto, $ip_cksum, $ip_src_host, $ip_dst_host);
		my ($packet) = $ip_header . $udp_packet;

		print "Generated IP Packet: ", (unpack('H*',$packet), "\n");

		# Send packet
		socket(RAW, AF_INET, SOCK_RAW, 255) or die ("Could not open socket for writing: $!");
		setsockopt(RAW, SOL_SOCKET, 1, 1);
		setsockopt(RAW, SOL_SOCKET, SO_BROADCAST, 1);
		my ($destination) = pack('S n a4 x8', AF_INET, $udp_dst_port, $ip_dst_host);
		send(RAW,$packet,0,$destination) or die ("Unable to Send: $!");

		print "Packet sent.\n";
	} # End foreach dest_list

	print "\n";
} # End main while loop
