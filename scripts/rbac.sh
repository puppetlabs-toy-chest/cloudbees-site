#!/bin/bash

# simple 3.7 NC classifier commands

declare -x PE_CERT=$(/opt/puppet/bin/puppet agent --configprint hostcert)
declare -x PE_KEY=$(/opt/puppet/bin/puppet agent --configprint hostprivkey)
declare -x PE_CA=$(/opt/puppet/bin/puppet agent --configprint localcacert)
declare -x PE_CERTNAME=$(/opt/puppet/bin/puppet agent --configprint certname)

declare -x NC_CURL_OPT="-s --cacert $PE_CA --cert $PE_CERT --key $PE_KEY --insecure"

find_guid()
{
  echo $(curl $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups| python -m json.tool |grep -C 2 "$1" | grep "id" | cut -d: -f2 | sed 's/[\", ]//g')
}

find_rbac_role_guid()
{
  echo $(curl $NC_CURL_OPT --insecure https://localhost:4433/rbac-api/v1/roles| python -m json.tool |grep -C 2 "$1" | grep "\"id\":" | cut -d: -f2 | sed 's/[\", ]//g')
}

read -r -d '' RBAC_ROLES << RBAC_ROLES_JSON
{"permissions": 
  [{"instance": "$(find_guid 'Application Web')",
     "action": "edit_classification",
     "object_type": "node_groups"},
    {"instance": "$(find_guid 'Application')",
     "action": "edit_child_rules",
     "object_type": "node_groups"},
    {"instance": "*", "action": "view", "object_type": "console_page"},
    {"instance": "$(find_guid 'Application Web')",
     "action": "view",
     "object_type": "node_groups"},
    {"instance": "$(find_guid 'Application DB')",
     "action": "edit_classification",
     "object_type": "node_groups"},
    {"instance": "$(find_guid 'Application DB')",
     "action": "view",
     "object_type": "node_groups"}],
  "group_ids": [],
  "user_ids": [],
  "display_name": "App Admins",
  "description": "Application administrators"
}
RBAC_ROLES_JSON

read -r -d '' RBAC_USERS << RBAC_USERS_JSON
{"email": "jblack@info.puppetlabs.demo",
  "login": "jblack",
  "role_ids": [$(find_rbac_role_guid 'App Admins')],
  "display_name": "Joe Black"
}
RBAC_USERS_JSON

echo "JSON:" $RBAC_USERS
curl -X POST -H 'Content-Type: application/json' -d "$RBAC_ROLES" $NC_CURL_OPT --insecure https://localhost:4433/rbac-api/v1/roles

curl -X POST -H 'Content-Type: application/json' -d "$RBAC_USERS" $NC_CURL_OPT --insecure https://localhost:4433/rbac-api/v1/users
