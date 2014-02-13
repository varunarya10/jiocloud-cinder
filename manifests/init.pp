#
# == Parameters
#
# [sql_idle_timeout]
#   Timeout when db connections should be reaped.
#   (Optional) Defaults to 3600.
#
# [use_syslog]
#   Use syslog for logging.
#   (Optional) Defaults to false.
#
# [log_facility]
#   Syslog facility to receive log lines.
#   (Optional) Defaults to LOG_USER.

class cinder (
  $sql_connection,
  $sql_idle_timeout            = '3600',
  $rpc_backend                 = 'cinder.openstack.common.rpc.impl_kombu',
  $control_exchange            = 'openstack',
  $rabbit_host                 = '127.0.0.1',
  $rabbit_port                 = 5672,
  $rabbit_hosts                = false,
  $rabbit_virtual_host         = '/',
  $rabbit_userid               = 'guest',
  $rabbit_password             = false,
  $qpid_hostname               = 'localhost',
  $qpid_port                   = '5672',
  $qpid_username               = 'guest',
  $qpid_password               = false,
  $qpid_sasl_mechanisms        = false,
  $qpid_reconnect              = true,
  $qpid_reconnect_timeout      = 0,
  $qpid_reconnect_limit        = 0,
  $qpid_reconnect_interval_min = 0,
  $qpid_reconnect_interval_max = 0,
  $qpid_reconnect_interval     = 0,
  $qpid_heartbeat              = 60,
  $qpid_protocol               = 'tcp',
  $qpid_tcp_nodelay            = true,
  $rpc_zmq_bind_address = '*',
  $rpc_zmq_contexts     = '1',
  $rpc_zmq_host = $hostname,
  $rpc_zmq_ipc_dir      = '/var/run/openstack',
  $rpc_zmq_matchmaker   = 'cinder.openstack.common.rpc.matchmaker.MatchMakerRing',
  $matchmaker_ringfile  = '/etc/nova/matchmaker.json',
  $rpc_zmq_port         = '9501',
  $package_ensure              = 'present',
  $api_paste_config            = '/etc/cinder/api-paste.ini',
  $use_syslog                  = false,
  $log_facility                = 'LOG_USER',
  $verbose                     = false,
  $debug                       = false
) {

  include cinder::params

  Package['cinder'] -> Cinder_config<||>
  Package['cinder'] -> Cinder_api_paste_ini<||>

  # this anchor is used to simplify the graph between cinder components by
  # allowing a resource to serve as a point where the configuration of cinder begins
  anchor { 'cinder-start': }

  package { 'cinder':
    ensure  => $package_ensure,
    name    => $::cinder::params::package_name,
    require => Anchor['cinder-start'],
  }

  file { $::cinder::params::cinder_conf:
    ensure  => present,
    owner   => 'cinder',
    group   => 'cinder',
    mode    => '0600',
    require => Package['cinder'],
  }

  file { $::cinder::params::cinder_paste_api_ini:
    ensure  => present,
    owner   => 'cinder',
    group   => 'cinder',
    mode    => '0600',
    require => Package['cinder'],
  }

  if $rpc_backend == 'cinder.openstack.common.rpc.impl_kombu' {

    if ! $rabbit_password {
      fail('Please specify a rabbit_password parameter.')
    }

    cinder_config {
      'DEFAULT/rabbit_password':     value => $rabbit_password, secret => true;
      'DEFAULT/rabbit_userid':       value => $rabbit_userid;
      'DEFAULT/rabbit_virtual_host': value => $rabbit_virtual_host;
      'DEFAULT/control_exchange':    value => $control_exchange;
    }

    if $rabbit_hosts {
      cinder_config { 'DEFAULT/rabbit_hosts':     value => join($rabbit_hosts, ',') }
      cinder_config { 'DEFAULT/rabbit_ha_queues': value => true }
    } else {
      cinder_config { 'DEFAULT/rabbit_host':      value => $rabbit_host }
      cinder_config { 'DEFAULT/rabbit_port':      value => $rabbit_port }
      cinder_config { 'DEFAULT/rabbit_hosts':     value => "${rabbit_host}:${rabbit_port}" }
      cinder_config { 'DEFAULT/rabbit_ha_queues': value => false }
    }
  }

  if $rpc_backend == 'cinder.openstack.common.rpc.impl_zmq' {
    cinder_config {
        'DEFAULT/rpc_zmq_bind_address':         value => $rpc_zmq_bind_address;
        'DEFAULT/rpc_zmq_contexts':             value => $rpc_zmq_contexts;
        'DEFAULT/rpc_zmq_host':                 value => $rpc_zmq_host;
        'DEFAULT/rpc_zmq_ipc_dir':              value => $rpc_zmq_ipc_dir;
        'DEFAULT/rpc_zmq_matchmaker':           value => $rpc_zmq_matchmaker;
        'DEFAULT/matchmaker_ringfile':          value => $matchmaker_ringfile;
        'DEFAULT/rpc_zmq_port':                 value => $rpc_zmq_port;
#    require => Service['nova-rpc-zmq-receiver']
    }

  }

  if $rpc_backend == 'cinder.openstack.common.rpc.impl_qpid' {

    if ! $qpid_password {
      fail('Please specify a qpid_password parameter.')
    }

    cinder_config {
      'DEFAULT/qpid_hostname':               value => $qpid_hostname;
      'DEFAULT/qpid_port':                   value => $qpid_port;
      'DEFAULT/qpid_username':               value => $qpid_username;
      'DEFAULT/qpid_password':               value => $qpid_password, secret => true;
      'DEFAULT/qpid_reconnect':              value => $qpid_reconnect;
      'DEFAULT/qpid_reconnect_timeout':      value => $qpid_reconnect_timeout;
      'DEFAULT/qpid_reconnect_limit':        value => $qpid_reconnect_limit;
      'DEFAULT/qpid_reconnect_interval_min': value => $qpid_reconnect_interval_min;
      'DEFAULT/qpid_reconnect_interval_max': value => $qpid_reconnect_interval_max;
      'DEFAULT/qpid_reconnect_interval':     value => $qpid_reconnect_interval;
      'DEFAULT/qpid_heartbeat':              value => $qpid_heartbeat;
      'DEFAULT/qpid_protocol':               value => $qpid_protocol;
      'DEFAULT/qpid_tcp_nodelay':            value => $qpid_tcp_nodelay;
    }

    if is_array($qpid_sasl_mechanisms) {
      cinder_config {
        'DEFAULT/qpid_sasl_mechanisms': value => join($qpid_sasl_mechanisms, ' ');
      }
    } elsif $qpid_sasl_mechanisms {
      cinder_config {
        'DEFAULT/qpid_sasl_mechanisms': value => $qpid_sasl_mechanisms;
      }
    } else {
      cinder_config {
        'DEFAULT/qpid_sasl_mechanisms': ensure => absent;
      }
    }
  }

  cinder_config {
    'DEFAULT/sql_connection':      value => $sql_connection, secret => true;
    'DEFAULT/sql_idle_timeout':    value => $sql_idle_timeout;
    'DEFAULT/verbose':             value => $verbose;
    'DEFAULT/debug':               value => $debug;
    'DEFAULT/api_paste_config':    value => $api_paste_config;
    'DEFAULT/rpc_backend':         value => $rpc_backend;
  }

  if $use_syslog {
    cinder_config {
      'DEFAULT/use_syslog':           value => true;
      'DEFAULT/syslog_log_facility':  value => $log_facility;
    }
  } else {
    cinder_config {
      'DEFAULT/use_syslog':           value => false;
    }
  }
}
