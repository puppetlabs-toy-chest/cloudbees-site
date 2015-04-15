class role::jenkins_enterprise {
  include ::profile::common
  include ::profile::firewall
  include ::profile::jenkins::demo
}
