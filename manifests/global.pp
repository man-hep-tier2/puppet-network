# == Class: network::global
#
# Configures /etc/sysconfig/network
#
# === Parameters:
#
#   $hostname       - optional - Changes the hostname (be aware that it will break
#                                something)
#                                Note: When you reboot/restart puppet, it will
#                                generate a new certificate and a new certificate
#                                request, based on the new hostname; you will have to
#                                sign it (if autosign is off).  You will also have to
#                                provide a new node definition in the manifest based
#                                on the new hostname.
#   $gateway        - optional - Sets the default gateway
#   $gatewaydev     - optional - Determines the device to use as the default gateway
#                                Overrides $gateway in network::global.  Must have
#                                $gateway defined in network::if or network::bond.
#   $ipv6gateway    - optional - Sets the default gateway for the IPv6 address - IPv6 must be enabled
#   $ipv6defaultdev - optional - Determines the device to use as the default gateway
#                                for IPV6 traffic.
#   $nisdomain      - optional - Configures the NIS domainname.
#   $vlan           - optional - yes|no to enable VLAN kernel module
#   $ipv6networking - optional - enables / disables IPv6 globally
#   $nozeroconf     - optional
#   $restart        - optional - defaults to true
#   $requestreopen  - optional - defaults to true
#
# === Actions:
#
#   Deploys the file /etc/sysconfig/network.
#
# === Requires:
#
#   Service['network']
#
# === Sample Usage:
#
#   class { 'network::global':
#     hostname       => 'host.domain.tld',
#     gateway        => '1.2.3.1',
#     gatewaydev     => 'eth0',
#     ipv6gateway    => '123:4567:89ab:cdef:123:4567:89ab:1',
#     ipv6defaultdev => 'eth0',
#     nisdomain      => 'domain.tld',
#     vlan           => 'yes',
#     ipv6networking => true,
#     nozeroconf     => 'yes',
#     requestreopen  => false,
#   }
#
# === TODO:
#
#
#
# === Authors:
#
# Mike Arnold <mike@razorsedge.org>
#
# === Copyright:
#
# Copyright (C) 2011 Mike Arnold, unless otherwise noted.
#
class network::global (
  Optional[Stdlib::Fqdn] $hostname = undef,
  Optional[Stdlib::IP::Address] $gateway = undef,
  Optional[String] $gatewaydev = undef,
  Optional[Stdlib::IP::Address::V6] $ipv6gateway = undef,
  Optional[String] $ipv6defaultdev = undef,
  Optional[String] $nisdomain = undef,
  Optional[Enum['yes','no']] $vlan = undef,
  Boolean $ipv6networking = false,
  Optional[String] $nozeroconf = undef,
  Boolean $restart = true,
  Boolean $requestreopen = true,
) {

  include '::network'

  case $::operatingsystem {
    /^(RedHat|CentOS|OEL|OracleLinux|SLC|Scientific|Rocky)$/: {
      case $::operatingsystemrelease {
        /^[456]/: { $has_systemd = false }
        default: { $has_systemd = true }
      }
    }
    'Fedora': {
      case $::operatingsystemrelease {
        /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17)$/: { $has_systemd = false }
        default: { $has_systemd = true }
      }
    }
    default: {}
  }

  if $hostname and $has_systemd {
    exec { 'hostnamectl set-hostname':
      command => "hostnamectl set-hostname ${hostname}",
      unless  => "hostnamectl --static | grep ^${hostname}$",
      path    => '/bin:/usr/bin',
    }
  }

  file { 'network.sysconfig':
    ensure  => 'present',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    path    => '/etc/sysconfig/network',
    content => template('network/network.erb'),
  }

  if $restart {
    File['network.sysconfig'] {
      notify  => Service['network'],
    }
  }
} # class global
