# == Class: network
#
# This module manages Red Hat/Fedora network configuration.
#
# === Parameters:
#
# None
#
# === Actions:
#
# Defines the network service so that other resources can notify it to restart.
#
# === Sample Usage:
#
#   include '::network'
#
# === Authors:
#
# Mike Arnold <mike@razorsedge.org>
#
# === Copyright:
#
# Copyright (C) 2011 Mike Arnold, unless otherwise noted.
#
class network {
  # Only run on RedHat derived systems.
  case $facts['os']['family'] {
    'RedHat': { }
    default: {
      fail('This network module only supports RedHat-based systems.')
    }
  }

  if Integer($facts['os']['release']['major']) > 7 {
    $service_name = 'NetworkManager'
    $neednm = 'yes'
  } else {
    $service_name = 'network'
    $neednm = 'no'
  }
  service { 'network':
    name       => $service_name,
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    provider   => 'redhat',
  }
} # class network

# == Definition: network_if_base
#
# This definition is private, i.e. it is not intended to be called directly
# by users.  It can be used to write out the following device files:
#  /etc/sysconfig/networking-scripts/ifcfg-eth
#  /etc/sysconfig/networking-scripts/ifcfg-eth:alias
#  /etc/sysconfig/networking-scripts/ifcfg-bond(master)
#
# === Parameters:
#
#   $ensure          - required - up|down
#   $ipaddress       - optional
#   $netmask         - optional
#   $macaddress      - required
#   $manage_hwaddr   - optional - defaults to true
#   $gateway         - optional
#   $noaliasrouting  - optional - defaults to false
#   $bootproto       - optional
#   $userctl         - optional - defaults to false
#   $mtu             - optional
#   $dhcp_hostname   - optional
#   $ethtool_opts    - optional
#   $bonding_opts    - optional
#   $isalias         - optional
#   $peerdns         - optional
#   $dns1            - optional
#   $dns2            - optional
#   $domain          - optional
#   $bridge          - optional
#   $scope           - optional
#   $linkdelay       - optional
#   $check_link_down - optional
#   $flush           - optional
#   $zone            - optional
#   $metric          - optional
#   $defroute        - optional
#   $promisc         - optional - defaults to false
#   $restart         - optional - defaults to true
#   $arpcheck        - optional - defaults to true
#
# === Actions:
#
# Performs 'service network restart' after any changes to the ifcfg file and $restart parameter is 'true'.
#
# === TODO:
#
#   HOTPLUG=yes|no
#   WINDOW=
#   SCOPE=
#   SRCADDR=
#   NOZEROCONF=yes
#   PERSISTENT_DHCLIENT=yes|no|1|0
#   DHCPRELEASE=yes|no|1|0
#   DHCLIENT_IGNORE_GATEWAY=yes|no|1|0
#   REORDER_HDR=yes|no
#
# === Authors:
#
# Mike Arnold <mike@razorsedge.org>
#
# === Copyright:
#
# Copyright (C) 2011 Mike Arnold, unless otherwise noted.
#
define network_if_base (
  Enum['up','down'] $ensure,
  String $macaddress,
  Optional[Stdlib::IP::Address] $ipaddress = undef,
  Optional[String] $netmask = undef,
  Boolean $manage_hwaddr = true,
  Optional[Stdlib::IP::Address] $gateway = undef,
  Boolean $noaliasrouting = false,
  Optional[Stdlib::IP::Address::V6] $ipv6address = undef,
  Optional[Stdlib::IP::Address::V6] $ipv6gateway = undef,
  Boolean $ipv6init = false,
  Boolean $ipv6autoconf = false,
  Optional[Array[Stdlib::IP::Address::V6]] $ipv6secondaries = undef,
  String $bootproto = 'none',
  Boolean $userctl = false,
  Optional[String] $mtu = undef,
  Optional[Stdlib::Fqdn] $dhcp_hostname = undef,
  Optional[String] $ethtool_opts = undef,
  Optional[String] $bonding_opts = undef,
  Boolean $isalias = false,
  Boolean $peerdns = false,
  Boolean $ipv6peerdns = false,
  Optional[String] $dns1 = undef,
  Optional[String] $dns2 = undef,
  Optional[String] $domain = undef,
  Optional[String] $bridge = undef,
  Optional[String] $linkdelay = undef,
  Optional[String] $scope = undef,
  Boolean $check_link_down = false,
  Boolean $flush = false,
  Optional[String] $defroute = undef,
  Optional[String] $zone = undef,
  Optional[String] $metric = undef,
  Boolean $promisc = false,
  Boolean $restart = true,
  Boolean $arpcheck = true,
) {

  include '::network'

  $neednm = $network::neednm
  $interface = $name

  # Deal with the case where $dns2 is non-empty and $dns1 is empty.
  if $dns2 {
    if !$dns1 {
      $dns1_real = $dns2
      $dns2_real = undef
    } else {
      $dns1_real = $dns1
      $dns2_real = $dns2
    }
  } else {
    $dns1_real = $dns1
    $dns2_real = $dns2
  }

  if $isalias {
    $onparent = $ensure ? {
      'up'    => 'yes',
      'down'  => 'no',
      default => undef,
    }
    $iftemplate = template('network/ifcfg-alias.erb')
  } else {
    $onboot = $ensure ? {
      'up'    => 'yes',
      'down'  => 'no',
      default => undef,
    }
    $iftemplate = template('network/ifcfg-eth.erb')
  }

  if $flush {
    exec { 'network-flush':
      user        => 'root',
      command     => "ip addr flush dev ${interface}",
      refreshonly => true,
      subscribe   => File["ifcfg-${interface}"],
      before      => Service['network'],
      path        => '/sbin:/usr/sbin',
    }
  }

  file { "ifcfg-${interface}":
    ensure  => 'present',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    path    => "/etc/sysconfig/network-scripts/ifcfg-${interface}",
    content => $iftemplate,
  }

  if $restart {
    File["ifcfg-${interface}"] {
      notify  => Service['network'],
    }
  }
} # define network_if_base

# == Definition: validate_ip_address
#
# This definition can be used to call is_ip_address on an array of ip addresses.
#
# === Parameters:
#
# None
#
# === Actions:
#
# Runs is_ip_address on the name of the define and fails if it is not a valid IP address.
#
# === Sample Usage:
#
# $ips = [ '10.21.30.248', '123:4567:89ab:cdef:123:4567:89ab:cdef' ]
# validate_ip_address { $ips: }
#
#define validate_ip_address {
#  if ! is_ip_address($name) { fail("${name} is not an IP(v6) address.") }
#} # define validate_ip_address
