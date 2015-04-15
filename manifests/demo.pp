class role::demo {
  include profile::firewall
  include profile::demo::web
  include profile::demo::db

  Class['profile::demo::db'] -> Class['profile::demo::web']
}
