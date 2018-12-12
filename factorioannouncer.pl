#!/usr/bin/perl
use strict;
use IO::Socket;
use List::Util "sum";

# This script listens to Factorio Lan Play announcement packets over localhost 
# and transmits them to an arbitrary list of broadcast addresses.
#
# Typical UDP Data Packet contents: 0x0f9585
# The data payload represents the server's game port to connect to and some 
# other data (presumably flags) in reverse byte order.  This means the payload
# shown here is read as 0x85950F.  If we use the first two bytes (for chars)
# and translate the hex code to decimal we get 34197 which is the default 
# Factorio game server port.
#
# The server IP address is the source address of the broadcast packet.  Because
# of this, this announcer script must be located on the same machine as the
# game server.
#
# PLEASE NOTE: This script (and the server) use DIRECTED BROADCASTS to perform
# the required task.  This means that while basic routers and other Layer 3
# devices will allow this traffic, firewalls (including basic consumer grade
# home routers) will not allow this broadcast to pass.  If you have a highly
# configurable firewall, you may be able to configure it to allow these 
# broadcasts for port 34196.  How to do that with your own gear is up to you to
# determine.


# Config - create a list of destination broadcast addresses to send to.
my @dest_list = ('192.168.220.63', '192.168.220.127', '192.168.220.191');

# Setup receiving socket
my $recvsock = IO::Socket::INET->new(
	Proto => "udp",
	LocalAddr => '127.0.0.1',
	LocalPort => 34196
	) or die "Can't open listening UDP Port: $!";
my ($datagram, $flags);

# Run main loop
while (1) {
	$recvsock->recv($datagram, 42, $flags);
	print "Received message from ",
		$recvsock->peerhost, ":", $recvsock->peerport,
		"  Flags: ", $flags || "none",
		"  Data: ", unpack('H*', $datagram),
		"\n";

	# Iterate over the destination subnet 
	foreach my $dst_host (@dest_list) {
		print "Sending notification to ", $dst_host, "... ";

		my $sendsock = IO::Socket::INET->new(
			Proto => "udp",
			LocalPort => 51111,
			PeerPort => 34196,
			PeerAddr => $dst_host
		) or die "Could not create sending socket: $!\n";
		$sendsock->setsockopt(SOL_SOCKET, SO_BROADCAST, 1);
		$sendsock->send($datagram) or die ("Unable to Send: $!");

		print "Done.\n"
	} # End foreach dest_list

	print "\n";
} # End main while loop
