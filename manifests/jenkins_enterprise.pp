class role::jenkins_enterprise {
  include ::profile::common
  include ::profile::pe_env
  include ::profile::firewall
  include ::profile::jenkins::demo
}
