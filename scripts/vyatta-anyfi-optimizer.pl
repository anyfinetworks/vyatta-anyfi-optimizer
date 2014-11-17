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
    $config_lines .= "port_range_start = $first\n";
    my $nports = $last - $first;
    $config_lines .= "port_range_count = $nports\n";

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

    $config_lines .= "rsa_keypair = $keyfile\n";

    return($config_lines);
}

sub setup_bridge
{
    my $bridge = shift;
    my $bridge_string = "bridge = $bridge\n";

    return($bridge_string);
}

sub setup_radius_server
{
    my $server = shift;
    my $port = shift;
    my $secret = shift;
    my $role = shift; # autz/acct
    my $radius_string = "";

    $radius_string .= "radius_" . $role . "_server = $server\n";

    $radius_string .= "radius_" . $role . "_port = $port\n";

    $radius_string .= "radius_" . $role . "_secret = $secret\n";

    return($radius_string);
}

sub setup_nas
{
    my $identifier = shift;
    my $ipaddr = shift;
    my $port = shift;
    my $nas_string = "";

    if( defined($identifier) )
    {
        $nas_string .= "nas_identifier = $identifier\n";
    }

    if( defined($ipaddr) )
    {
        $nas_string .= "nas_ip_address = $ipaddr\n";
    }

    if( defined($port) )
    {
        $nas_string .= "nas_port = $port\n";
    }

    return($nas_string);
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

    # RSA key pair
    my $keypairfile = $config->returnValue("rsa-key-pair file");
    if( !$keypairfile )
    {
    error("must specify an RSA key pair file.");
    }
    $config_string .= setup_key_pair($instance, $keypairfile);

    # Bridge
    my $bridge = $config->returnValue("bridge");
    if( !$bridge )
    {
        error("must configure a breakout bridge interface.");
    }
    $config_string .= setup_bridge($bridge);

    # Authorization
    if( $config->exists("authorization") )
    {
        my @servers = $config->listNodes("authorization radius-server");

        if( scalar(@servers) != 1 )
        {
            error("must specify exactly one radius authorization server.");
        }
        else
        {
            my $server = shift(@servers);
            my $port = $config->returnValue("authorization radius-server $server port");
            my $secret = $config->returnValue("authorization radius-server $server secret");

            $config_string .= setup_radius_server($server, $port, $secret, "autz");
        }
    }

    # Accounting settings
    if( $config->exists("accounting") )
    {
        my @servers = $config->listNodes("accounting radius-server");

        if( scalar(@servers) != 1 )
        {
            error("must specify exactly one radius accounting server.");
        }
        else
        {
            my $server = shift(@servers);
            my $port = $config->returnValue("accounting radius-server $server port");
            my $secret = $config->returnValue("accounting radius-server $server secret");

            $config_string .= setup_radius_server($server, $port, $secret, "acct");
        }
    }

    # Network Access Server
    if( $config->exists("nas") )
    {
        my $identifier = $config->returnValue("nas identifier");
        my $ipaddr = $config->returnValue("nas ip-address");
        my $port = $config->returnValue("nas port");

        $config_string .= setup_nas($identifier, $ipaddr, $port);
    }

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
