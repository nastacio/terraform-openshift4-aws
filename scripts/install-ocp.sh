#!/bin/bash

set -x

: "${aws_region:=${1}}"
: "${aws_access_key_id:=${2}}"
: "${aws_secret_access_key:=${3}}"
: "${openshift_install_version:=${4}}"
: "${cluster_name:=${5}}"
: "${network_domain:=${6}}"
: "${cluster_worker_count:=${7}}"
: "${cluster_worker_flavor:=${8}}"
: "${sdlc_env:=${9}}"
: "${subnet_public:=${10}}"
: "${subnet_private:=${11}}"
: "${ssh_key:=${12}}"
: "${registry_url:=${13}}"
: "${registry_username:=${14}}"
: "${registry_password:=${15}}"

installer_platform=linux


#
# Prints a formatted message with the timestamp of execution
#
function log() {
    local msg=${1}
    echo "$(date +%Y-%m-%dT%H:%M:%S%z): ${msg}"
}


#
#
#
function install_podman() {
    dnf install -y @container-tools \
    && podman version \
    || return 1
}


#
# If the OC CLI is older than 4.5, then installs the latest version
#
function check_install_oc() {
    local install=0

    echo "INFO: Checking OpenShift client installation..." 
    type -p oc > /dev/null 2>&1 || install=1
    if [ ${install} -eq 0 ]; then
        oc_version=$(oc version | grep "Client Version" | cut -d ":" -f 2 | tr -d " ")
        if [ "${oc_version}" == "" ] ||
           [[ ${oc_version} == "3."* ]] ||
           [[ ${oc_version} == "4.1."* ]] ||
           [[ ${oc_version} == "4.2."* ]] ||
           [[ ${oc_version} == "4.3."* ]] ||
           [[ ${oc_version} == "4.4."* ]]; then
            echo "INFO: OpenShift client is older than 4.5." 
            install=1
        fi
    fi

    if [ ${install} -eq 1 ]; then
        echo "INFO: Installing latest OpenShift client..." 
        curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | tar xzf - -C /usr/bin \
        && echo "INFO: Installed latest OpenShift client." \
        && oc version \
        && install=0
    fi

    if [ ${install} -eq 1 ]; then
        echo "ERROR: Installation of oc CLI failed."
    fi

    return ${install}
}


#
#
#
function install_installer() {
    curl -sL https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${openshift_install_version}/openshift-install-${installer_platform}.tar.gz | tar xzf - -C /usr/bin \
    && openshift-install version 
}


#
#
#
function cache_aws_credentials() {
    mkdir -p ~/.aws
    cat << EOF > ~/.aws/credentials
[default]
aws_access_key_id = ${aws_access_key_id}
aws_secret_access_key = ${aws_secret_access_key}
EOF
}


#
#
#
function install_ocp() {
    result=0

    install_dir="${WORKDIR}/sdlc"
    install_config="${install_dir}/install-config.yaml"
    mirror_pull_secret="${install_dir}/mirror-secret.json"
    
    mkdir -p "${install_dir}" \
    && podman login --authfile "${mirror_pull_secret}" \
        -u "${registry_username}" \
        -p "${registry_password}" \
        "${registry_url}" \
        --tls-verify=false --verbose \
    && pull_secret=$(cat "${mirror_pull_secret}" | tr -d "\n" | tr -d " ") \
    && cp /tmp/install-config-template.yaml "${install_config}" \
    && sed -i "s|%%NETWORK_DOMAIN%%|${network_domain}|" "${install_config}" \
    && sed -i "s|%%CLUSTER_WORKERS%%|${cluster_worker_count}|" "${install_config}" \
    && sed -i "s|%%CLUSTER_NAME%%|${cluster_name}|" "${install_config}" \
    && sed -i "s|%%AWS_REGION%%|${aws_region}|" "${install_config}" \
    && sed -i "s|%%SDLC_ENV%%|${sdlc_env}|" "${install_config}"
    sed -i "s|%%SUBNET_PUBLIC%%|${subnet_public}|" "${install_config}" \
    && sed -i "s|%%SUBNET_PRIVATE%%|${subnet_private}|" "${install_config}" \
    && sed -i "s|%%PULL_SECRET%%|${pull_secret}|" "${install_config}" \
    && sed -i "s|%%SSH_KEY%%|${ssh_key}|" "${install_config}" \
    && openshift-install create cluster --dir="${install_dir}" \
    || result=1

    if [ ${result} -eq 1 ]; then
        echo "ERROR: Installation of OCP is not working"
    fi

    return ${result}
}


#
# Clean up at end of task
#
cleanRun() {
    cd "${original_dir}"
    if [ -n "${WORKDIR}" ]; then
        rm -rf "${WORKDIR}"
    fi
}
trap cleanRun EXIT

#
#
#
# WORKDIR=$(mktemp -d) || exit 1
WORKDIR=/tmp

install_podman \
&& check_install_oc \
&& install_installer \
&& cache_aws_credentials \
&& install_ocp \
|| exit $?
