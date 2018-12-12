#!/usr/bin/perl -w

use strict;
use IO::Socket;

print "Startup.\n";
my $mysock = IO::Socket::INET->new(
	Proto => "udp", 
	LocalPort => 34196 
	) or die "Can't make UDP server: $@";
print "Listening.\n";

my ($datagram,$flags);
my ($facflags, $facport1, $facport2, $facportall);
while (1) {
	$mysock->recv($datagram,42,$flags);
	printf ("Got message from %-15s", $mysock->peerhost);
	print " - Flags: ", $flags || "none";
	print ", Raw Data: ", unpack('H*', $datagram);

	($facflags, $facport2, $facport1) = unpack('H2 H2 H2', $datagram);
	print ", Factorio Port: ", hex($facport1 . $facport2);
	printf (", Factorio Flags: %08b", hex($facflags));

	print "\n";
}

