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

my $conf_dir = "/etc/";

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

sub setup_key
{
    # TODO: Break-out of Internet-bound traffic
    return("");
}

sub setup_subnet
{
    # TODO: Break-out of Internet-bound traffic
    return("");
}

sub setup_pps
{
    # TODO: Break-out of Internet-bound traffic
    return("");
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
        # Public key
        my $pubkey = $config->returnValue("breakout public-key");
        if( !$pubkey )
        {
            error("must specify public key.");
        }
        $config_string .= setup_key('public', $pubkey);

        # Private key
        my $privkey = $config->returnValue("breakout private-key");
        if( !$privkey )
        {
            error("must specify private key.");
        }
        $config_string .= setup_key('private', $privkey);

        # NAT subnet
        my $subnet = $config->returnValue("breakout subnet");
        if( !$subnet )
        {
            error("must specify NAT subnet.");
        }
        $config_string .= setup_subnet($subnet);

        # NAT port allocation strategy
        if( $config->exists("breakout ports") )
        {
            # Allocate fixed number of ports per SDWN service
            my $pps = $config->returnValue("breakout ports per-service");

            # TODO: Other port allocation strategies?

            if( !$pps )
            {
                error("must configure a NAT port allocation strategy.");
            }
            $config_string .= setup_pps($pps);
        }
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
