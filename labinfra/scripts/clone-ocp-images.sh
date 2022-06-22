#!/bin/sh

# https://www.youtube.com/watch?v=j5e4OT71N0A

set -x

: "${registry_url:=${1}}"
: "${registry_username:=${2}}"
: "${registry_password:=${3}}"
: "${rhel_pull_secret:=${4}}"
: "${openshift_version:=${5}}"


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
# https://access.redhat.com/documentation/en-us/openshift_container_platform/4.10/html-single/installing/index#installing-mirroring-creating-registry
#
function clone_ocp() {
    result=0

    echo "INFO: Cloning OCP images"
    quay_root_dir=/data/quay/images

    running_status=0
    mirror_pull_secret=pull-secret.txt \
    && podman login --authfile "${mirror_pull_secret}" \
        -u "${registry_username}" \
        -p "${registry_password}" \
        "${registry_url}:443" \
        --tls-verify=false \
    && echo "INFO: Registry is working" \
    || {
        echo "ERROR: Registry is not working" \
        return 1
    }

    export LOCAL_REGISTRY="${registry_url/https:\/\//}"
    export LOCAL_REPOSITORY=ocp4/openshift4
    export PRODUCT_REPO=openshift-release-dev
    # https://console.redhat.com/openshift/install/pull-secret
    export LOCAL_SECRET_JSON=mirror-registry.conf
    export RELEASE_NAME="ocp-release"
    export ARCHITECTURE=x86_64
    
    quay_images_dir="${quay_root_dir}/removable" \
    && mkdir -p "${quay_images_dir}" \
    && export REMOVABLE_MEDIA_PATH="${quay_images_dir}" \
    && echo "INFO: Generating pull secret." \
    && echo "${rhel_pull_secret}" | sed "s|'|\"|g" | jq -M ".auths += $(cat "${mirror_pull_secret}").auths" > "${LOCAL_SECRET_JSON}" \
    && chmod 600 "${LOCAL_SECRET_JSON}" \
    && cat "${LOCAL_SECRET_JSON}" \
    && echo "INFO: Reviewing images..." \
    && oc adm release mirror -a ${LOCAL_SECRET_JSON}  \
            --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${openshift_version}-${ARCHITECTURE} \
            --to="${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}" \
            --to-release-image="${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${openshift_version}-${ARCHITECTURE}" \
            --dry-run \
    && echo "INFO: Mirroring images..." \
    && oc adm release mirror \
            --insecure=true \
            -a ${LOCAL_SECRET_JSON} \
            --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${openshift_version}-${ARCHITECTURE} \
            --to="${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}" \
            --to-release-image="${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${openshift_version}-${ARCHITECTURE}" \
    && echo "INFO: Mirrored images successfully." \
    || result=1

    return ${result}
}

result=0

sudo yum install jq -y \
&& check_install_oc \
&& clone_ocp \
|| result=1

exit ${result}
