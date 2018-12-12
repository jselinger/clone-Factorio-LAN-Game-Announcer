# Factorio LAN Game Announcer

  

The game Factorio uses UDP broadcast strategy for announcing game servers to the local subnet to support the game finding local LAN games to play. These scripts support relaying the broadcasts to additional subnets not in the local broadcast doman.

  

This repository contains multiple Perl scripts, however, only one should be used at any given time.

 - factorioannouncer.pl
	 - This script is the simplest to setup and run.  It sits on the Factorio game server it is to announce and when it receives the broadcast packet from the server, it re-transmits the broadcast packet to the configured broadcast addresses.
 - factoriorelay.pl
	 - This script is a more complex version of factorioannouncer.pl.  This script can sit on any machine in the same subnet as the Factorio game server and transmit those broadcast packets to another subnet.  It achieves this by spoofing the source IP of the packet to be the same as the server that sent the original packet thereby tricking the game client to connect back to the actual game server.
 - factoriolistener.pl
	 - This is a simple diagnostic script.  It listens on the Factorio LAN game announcment port (UDP 34196) and tells you when it has been received.
 - udpsender.pl
	 - This script is another diagnostic script.  This script sends a single UDP packet on port 34196 to the configured address.  The destination address can be either a single IP or a broadcast address.

## Installation
Each of these scripts are Perl based and therefore require the Perl interpreter.  They use the IO::Socket Perl module which should be included on most machines.

Each of these scripts run as simple console scripts and have no dependencies outside of perl and the Perl modules.  Some of these scripts will run in a loop and are stopped with a simple Ctrl-C.  If you wish to run these in the background, most systems have the ability to run simple scripts in the background.

Since these scripts (more accurately, the game) use DIRECTED BROADCASTS to achieve their goals, you may have to adjust your network security to allow them.  Most routers will allow these broadcasts through, however, almost all security appliances (firewalls, IDS/IPS, etc) will block a directed broadcasts due to security concerns.

**PLEASE BE CAUTIOUS** - The reason directed broadcasts are blocked by any sane security appliance is due to the possibility of broadcast attacks associated with the usage of a directed broadcast.  Be sure you understand these implications before allowing these types of packets on your network.  NEVER ALLOW THEM FROM THE INTERNET.

Hint:  On a *nix based router, you may have to update your sysctl to set 
net.inet.ip.directed-broadcast=1

## Configuration
Each of these scripts has a section at the top to configure the destination IP addresses.  These addresses could be a single IP address or broadcast addresses. Simply configure the desired destination addresses and run the script.

 - The udpsender.pl script is configured by setting the $dst_ip variable
 - The factorioannouncer.pl and factoriorelay.pl scripts are configured by setting the @dest_list variable.

In a typical home network, the broadcast IP address would end in 255.  For example, if a machine in the target network is 192.168.1.14, then the broadcast address is most likely 192.168.1.255.  For further information about this, please see your network administrator.