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


read -r -d '' PE_MASTER_POST << MASTER_JSON
{
  "classes": {
    "ldap": { },
    "pe_repo": { },
    "pe_repo::platform::el_6_x86_64": {},
    "pe_repo::platform::el_7_x86_64": {},
    "pe_repo::platform::ubuntu_1204_amd64": {},
    "pe_repo::platform::ubuntu_1404_amd64": {},
    "puppet_enterprise::profile::master": { },
    "puppet_enterprise::profile::master::mcollective": {},
    "puppet_enterprise::profile::mcollective::peadmin": {},
    "role::master": {}
  },
  "environment": "production",
  "environment_trumps": false,
  "id": "$(find_guid 'PE Master')",
  "name": "PE Master",
  "parent": "$(find_guid 'PE Infrastructure')",
  "rule": [
    "or", 
    [ "=", "name", "$PE_CERTNAME" ]
  ],
  "variables": {}
}
MASTER_JSON

read -r -d '' DB_SERVER_POST << DB_SERVER_JSON
{"environment_trumps": false,
  "parent": "$(find_guid 'default')",
  "name": "DB Server",
  "rule": ["or", ["=", "name", "db.pdx.puppetlabs.demo"]],
  "variables": {},
  "environment": "production",
  "description": "Database server",
  "classes": 
   {"profile::mysql_server": 
     {"root_password": "mysql_secret_password",
      "override_options": {"mysqld": {"bind-address": "0.0.0.0"}}
     }
   }
}
DB_SERVER_JSON

read -r -d '' APPLICATION_POST << APPLICATION_JSON
{"environment_trumps": false,
  "parent": "$(find_guid 'default')",
  "name": "Application",
  "variables": {},
  "environment": "production",
  "description": "Application parent hierarchy",
  "classes": 
   {"profile::wordpress": 
     {"db_user": "wordpress",
      "db_password": "supersecret",
      "db_name": "wordpress"}
   }
}
APPLICATION_JSON

read -r -d '' APPLICATION_WEB_POST << APPLICATION_WEB_JSON
{ "parent": "$(find_guid 'Application')",
  "name": "Application Web",
  "description": "Application's Web Components",
  "rule": ["or", ["=", "name", "app1.pdx.puppetlabs.demo"]],
  "classes": {"profile::wordpress::app": {}}
}
APPLICATION_WEB_JSON

read -r -d '' APPLICATION_DB_POST << APPLICATION_DB_JSON
{ "parent": "$(find_guid 'Application')",
  "name": "Application DB",
  "description": "Application's DB",
  "rule": ["or", ["=", "name", "db.pdx.puppetlabs.demo"]],
  "classes": {"profile::wordpress::db": {}}
}
APPLICATION_DB_JSON

read -r -d '' JENKINS_POST << JENKINS
{ "parent": "$(find_guid 'default')",
  "name": "Jenkins",
  "description": "Jenkins",
  "rule": ["or", ["=", "name", "jenkins.infra.puppetlabs.demo"]],
  "classes": {"profile::jenkins_enterprise": {}}
}
JENKINS

read -r -d '' PE_LINUX_GROUP << LINUX_JSON
{
    "classes": {
      "profile::pe_env": {},
      "ntp": {}
    },
    "environment": "production",
    "environment_trumps": false,
    "name": "Linux Servers",
    "parent": "00000000-0000-4000-8000-000000000000",
    "rule": [
           "and",
        [
            "not",
            [
                "=",
                [
                    "fact",
                    "clientcert"
                ],
                "$PE_CERTNAME"
            ]
        ],
        [
            "=",
            [
                "fact",
                "kernel"
            ],
            "Linux"
        ] 
    ],
    "variables": {}
}
LINUX_JSON

read -r -d '' PE_WINDOWS_GROUP << WINDOWS_JSON
{
    "classes": {
    "chocolatey": {}
    },
    "environment": "production",
    "environment_trumps": false,
    "name": "Windows Servers",
    "parent": "00000000-0000-4000-8000-000000000000",
    "rule": [
        "and",
        [
            "=",
            [
                "fact",
                "kernel"
            ],
            "windows"
        ]
    ],
    "variables": {}
}
WINDOWS_JSON

read -r -d '' PE_MCO_GROUP << MCO_JSON
{
    "classes": {
        "puppet_enterprise::profile::mcollective::agent": {}
    },
    "environment": "production",
    "environment_trumps": false,
    "id": "$(find_guid 'PE MCollective')",
    "name": "PE MCollective",
    "parent": "$(find_guid 'PE Infrastructure')",
    "rule": [
        "and",
        [
            "=",
            [
                "fact",
                "is_admin"
            ],
            "true"
        ],
        [
            "~",
            [
                "fact",
                "pe_version"
            ],
            ".+"
        ]
    ],
    "variables": {}
}
MCO_JSON


curl -X POST -H 'Content-Type: application/json' -d "$PE_MASTER_POST" $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups/$(find_guid 'PE Master')

curl -X POST -H 'Content-Type: application/json' -d "$JENKINS_POST" $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups

curl -X POST -H 'Content-Type: application/json' -d "$APPLICATION_POST" $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups
curl -X POST -H 'Content-Type: application/json' -d "$APPLICATION_WEB_POST" $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups
curl -X POST -H 'Content-Type: application/json' -d "$APPLICATION_DB_POST" $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups

# is admin fact is apparently broken right now on windows / inconsistent based on mco vs service run, etc
#curl -X POST -H 'Content-Type: application/json' -d "$PE_MCO_GROUP" $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups/$(find_guid 'PE MCollective')

curl -X POST -H 'Content-Type: application/json' -d "$PE_LINUX_GROUP" $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups
curl -X POST -H 'Content-Type: application/json' -d "$PE_WINDOWS_GROUP" $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/groups

