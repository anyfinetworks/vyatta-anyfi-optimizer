#!/usr/bin/perl
#
# vyatta-anyfi-optimizer.pl: anyfi-optimizer config generator
#
# Maintainer: Anyfi Networks <eng@anyfinetworks.com>
#
# Copyright (C) 2013-2014 Anyfi Networks AB. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use lib "/opt/vyatta/share/perl5/";

use strict;
use warnings;
use Vyatta::Config;
use Getopt::Long;
use NetAddr::IP;
use IO::File;

sub error
{
    my $msg = shift;
    print STDERR "Error configuring anyfi optimizer: $msg\n";
    exit(1);
}

sub setup_port_range
{
    my $port_range = shift;
    my $config_lines = "";
    my ($first, $last) = split('-', $port_range);

    # NOTE: Handing of "service anyfi optimizer $VAR(@) port-range"
    #       is split between templates and this script. First UDP
    #       port is used for SDWN control plane (specified as a
    #       command line option from template), while the rest are
    #       for relaying of SDWN data plane tunnels.
    $first += 1;
    $config_lines .= "ports_first = $first\n";
    my $nports = $last - $first;
    $config_lines .= "ports = $nports\n";

    return($config_lines);
}

sub setup_key_pair
{
    my $instance = shift;
    my $keyfile = shift;
    my $pubkeyfile = "/var/run/anyfi-optimizer-$instance.pub";
    my $config_lines = "";

    system("openssl rsa -in $keyfile -pubout -out $pubkeyfile 2> /dev/null") &&
        error("could not extract public key from RSA key pair.");

    $config_lines .= "keyfile = $keyfile\n";
    $config_lines .= "pubkeyfile = $pubkeyfile\n";

    return($config_lines);
}

# TUN ioctl constants:
use constant TUNSETIFF     => 0x400454ca;
use constant TUNSETPERSIST => 0x400454cb;
use constant IFF_TUN       => 0x0001;
use constant IFF_PERSIST   => 0x0100;
use constant STRUCT_IFREQ  => 'Z16 s';

sub create_tun
{
    my $basename = shift;
    my $ifname;

    my $fh  = new IO::File('/dev/net/tun', 'r+');
    my $ifr = pack(STRUCT_IFREQ, $basename, IFF_TUN);

    ioctl $fh, TUNSETIFF, $ifr
        or error("Can't create tun: $!");

    $ifname = (unpack(STRUCT_IFREQ, $ifr))[0];

    $ifr = pack(STRUCT_IFREQ, $ifname, IFF_PERSIST);

    ioctl $fh, TUNSETPERSIST, $ifr
        or error("Can't make tun persistant: $!");

    return($ifname);
}

sub setup_nat
{
    my $subnet = shift;
    my $pps = shift;
    my $ips = new NetAddr::IP($subnet);
    my $config_lines = "";

    my $tunif = create_tun('opt%d');
    my $llidx = substr($tunif, 3) + 1;

    system("route del -net $subnet 2> /dev/null") if (scalar(@$ips) > 1);
    system("route del -host $subnet 2> /dev/null") if (scalar(@$ips) == 1);

    system("ifconfig $tunif inet 169.254.$llidx.1");
    system("ifconfig $tunif dstaddr 169.254.$llidx.2");
    system("route add -net $subnet gw 169.254.$llidx.2") if (scalar(@$ips) > 1);
    system("route add -host $subnet gw 169.254.$llidx.2") if (scalar(@$ips) == 1);

    $config_lines .= "nat_if0 = tun/$tunif ip ";
    $config_lines .= join(',', @$ips);
    $config_lines .= "\n";

    # Remove unwanted /32 specifier on all IP addresses
    $config_lines =~ s|/32||g;

    if( $pps )
    {
        $config_lines .= "nat.params.max_connections_per_lan = $pps\n";
    }

    return($config_lines);
}

sub generate_config
{
    my $instance = shift;
    my $config = new Vyatta::Config();
    $config->setLevel("service anyfi optimizer $instance");

    my $config_string = "";

    # SDWN port range
    my $port_range = $config->returnValue("port-range");
    if( !$port_range )
    {
        error("must specify SDWN port range.");
    }
    $config_string .= setup_port_range($port_range);

    # Breakout of Internet-bound traffic
    if( $config->exists("breakout") )
    {
        # RSA key pair
        my $keypairfile = $config->returnValue("breakout rsa-key-pair file");
        if( !$keypairfile )
        {
            error("must specify an RSA key pair file.");
        }
        $config_string .= setup_key_pair($instance, $keypairfile);

        # NAT subnet
        my $subnet = $config->returnValue("breakout subnet");
        if( !$subnet )
        {
            error("must specify NAT subnet.");
        }

        # NAT port allocation strategy
        my $pps = $config->returnValue("breakout ports per-service");
        if( $config->exists("breakout ports") && !$pps )
        {
            error("must configure a NAT port allocation strategy.");
        }

        $config_string .= setup_nat($subnet, $pps);
    }

    # TODO: Remove UUID...
    $config_string .= "uuid = " . `cat /proc/sys/kernel/random/uuid`;

    return($config_string);
}

sub apply_config
{
    my ($instance, $config_file) = @_;
    my $config = generate_config($instance);
    open(HANDLE, ">$config_file") || error("could not open $config_file for writing.");
    print HANDLE $config;
    close(HANDLE);
}

my $instance;
my $config_file;

GetOptions(
    "instance=s" => \$instance,
    "config=s" => \$config_file
);

if( (! $instance) || (! $config_file ) )
{
    error("Usage: --instance=<instance name> --config=</path/to/config_file>");
}

apply_config($instance, $config_file);
