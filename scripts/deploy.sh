#!/bin/bash

# this is the universal configuration script
# untar the environments code, and this now 
# moves everything it needs into place
# and configures the master

working_dir=$(basename $(cd $(dirname $0) && pwd))
containing_dir=$(cd $(dirname $0)/.. && pwd)
basename="${containing_dir}/${working_dir}"

# see if we are already in our working directory
if [ $basename != '/etc/puppetlabs/puppet/environments/production/scripts' ]; then
  /bin/cp -Rfu $basename/../* /etc/puppetlabs/puppet/environments/production/
fi

/opt/puppet/bin/puppet config set disable_warnings deprecations --section main

/opt/puppet/bin/puppet config set environment_timeout 0 --section main

/opt/puppet/bin/puppet config set hiera_config \$confdir/environments/production/hiera.yaml --section main

/opt/puppet/bin/puppet resource service pe-puppetserver ensure=stopped
/opt/puppet/bin/puppet resource service pe-puppetserver ensure=running

/opt/puppet/bin/puppet apply --exec 'include role::master'

/opt/puppet/bin/puppet apply /etc/puppetlabs/puppet/environments/production/staging.pp

/opt/puppet/bin/puppet apply /etc/puppetlabs/puppet/environments/production/offline_repo.pp

/bin/bash $basename/refresh_classes.sh
/bin/bash $basename/classifier.sh
/bin/bash $basename/rbac.sh

/bin/bash $basename/connect_ds.sh

/opt/puppet/bin/puppet agent --onetime --no-daemonize --color=false --verbose
