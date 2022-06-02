#!/bin/bash

set -x 

cli_type=${1}
destination_path=${2}
openshift_installer_url=${3}
 
if [ -f "${destination_path}/openshift-install" ];
then
  echo "INFO: Reusing cached openshift-install utility"
  exit 0
fi

platform=""
case $(uname -s) in
  Linux)
    platform=linux
    ;;
  Darwin)
    platform=mac
    ;;
  *) 
    echo "ERROR: Unsupported platform: $(uname -s)"
    exit 1
    ;;
esac

curl -sL ${openshift_installer_url}/openshift-${cli_type}-${platform}.tar.gz  | tar xzf - -C ${destination_path} \
&& rm -f ${destination_path}/robots*.txt* ${destination_path}/README.md
