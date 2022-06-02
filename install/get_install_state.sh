#!/bin/bash

function parse_input() {
  input=$(jq -r .)
  infra_id=$(echo "${input}" | jq -r .infra_id)
  openshift_install_state_file=$(echo "${input}" | jq -r .openshift_install_state_file)

  echo "$input" > /tmp/input.json
}

function print_output() {
    if [ -n "${infra_id}" ]
    then
        echo "{ \"InfraID\" : \"${infra_id}\" }"
    else
        jq -rM ".\"*installconfig.ClusterID\"" "${openshift_install_state_file}"
    fi
}

parse_input \
&& print_output
