#!/usr/bin/perl

use strict;
use IO::Socket;

my $dst_ip = '192.168.223.255';

my $sendsock = IO::Socket::INET->new(
	Proto => "udp",
	LocalPort => 51111,
	PeerPort => 34196,
	PeerAddr => $dst_ip
) or die "Could not create sending socket: $!";
$sendsock->setsockopt(SOL_SOCKET, SO_BROADCAST, 1);
$sendsock->send("HELLO") or die "Unable to send: $!";
