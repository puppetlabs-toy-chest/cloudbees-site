class role::pemaster {
  include ::profile::common
  include ::profile::firewall
  include ::profile::pe_master
}
