class role::jenkins_enterprise {
  include ::profile::firewall
  include ::profile::jenkins::demo
}
