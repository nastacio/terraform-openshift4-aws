resource "null_resource" "generate_manifests" {
  triggers = {
    install_config =  data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    local_file.install_config
    # null_resource.aws_credentials,
  ]

  provisioner "local-exec" {
    command = "rm -rf ${path.root}/installer-files//temp"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${path.root}/installer-files//temp"
  }

  provisioner "local-exec" {
    command = "mv ${path.root}/installer-files//install-config.yaml ${path.root}/installer-files//temp"
  }

  provisioner "local-exec" {
    command = "${path.module}/get_openshift_cli.sh install ${path.root}/installer-files ${var.openshift_installer_url}"
  }

  provisioner "local-exec" {
    when    = create
    command = "${path.root}/installer-files//openshift-install --dir=${path.root}/installer-files//temp create manifests"
  }
}

# because we're providing our own control plane machines, remove it from the installer
resource "null_resource" "manifest_cleanup_control_plane_machineset" {
  depends_on = [
    null_resource.generate_manifests
  ]

  triggers = {
    install_config =  data.template_file.install_config_yaml.rendered
    local_file     =  local_file.install_config.id
  }

  provisioner "local-exec" {
    command = "rm -f ${path.root}/installer-files//temp/openshift/99_openshift-cluster-api_master-machines-*.yaml"
  }
}

# build the bootstrap ignition config
resource "null_resource" "generate_ignition_config" {
  depends_on = [
    null_resource.manifest_cleanup_control_plane_machineset,
    local_file.airgapped_registry_upgrades,
    local_file.create_worker_machineset,
    local_file.airgapped_registry_upgrades,
    local_file.cluster-dns-02-config,
    local_file.create_infra_machineset,
    local_file.cluster-monitoring-configmap,
    local_file.configure-image-registry-job-serviceaccount,
    local_file.configure-image-registry-job-clusterrole,
    local_file.configure-image-registry-job-clusterrolebinding,
    local_file.configure-image-registry-job,
    local_file.configure-ingress-job-serviceaccount,
    local_file.configure-ingress-job-clusterrole,
    local_file.configure-ingress-job-clusterrolebinding,
    local_file.configure-ingress-job,
  ]

  triggers = {
    install_config                   =  data.template_file.install_config_yaml.rendered
    local_file_install_config        =  local_file.install_config.id
  }

  provisioner "local-exec" {
    command = "mkdir -p ${path.root}/installer-files//temp"
  }

  provisioner "local-exec" {
    command = "rm -rf ${path.root}/installer-files//temp/_manifests ${path.root}/installer-files//temp/_openshift"
  }

  provisioner "local-exec" {
    command = "cp -r ${path.root}/installer-files//temp/manifests ${path.root}/installer-files//temp/_manifests"
  }

  provisioner "local-exec" {
    command = "cp -r ${path.root}/installer-files//temp/openshift ${path.root}/installer-files//temp/_openshift"
  }

  provisioner "local-exec" {
    command = "${path.root}/installer-files//openshift-install --dir=${path.root}/installer-files//temp create ignition-configs"
  }
}

resource "null_resource" "delete_aws_resources" {
  triggers = {
    infra_id = data.external.extractInfrastructureID.result.InfraID
  }

  depends_on = [
    null_resource.cleanup
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/aws_cleanup.sh ${self.triggers.infra_id}"
    #command = "${path.root}/installer-files//openshift-install --dir=${path.root}/installer-files/temp destroy cluster"
  }

}

resource "null_resource" "cleanup" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${path.root}/installer-files//temp"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.root}/installer-files//openshift-install"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.root}/installer-files//oc"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.root}/installer-files//kubectl"
  }
}

data "local_file" "bootstrap_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  "${path.root}/installer-files//temp/bootstrap.ign"
}

data "local_file" "master_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  "${path.root}/installer-files//temp/master.ign"
}

data "local_file" "worker_ign" {
  depends_on = [
    null_resource.generate_ignition_config
  ]

  filename =  "${path.root}/installer-files//temp/worker.ign"
}

data "local_file" "openshift_install_state_json" {
  count = var.infra_id == "" ? 1 : 0
 
  depends_on = [
    null_resource.generate_manifests
  ]

  filename = "${path.root}/installer-files/temp/.openshift_install_state.json"
}

#
# Writes the "ClusterId" element of openshift_install_state.json into the result.
#
# It gives precedence to the variable over the content of the file in the disk.
# That variable should be added to the tf.vars file *after* the first invocation
# of "terraform apply" in case you need to delete the temporary "installer-files"
# folder, such as when relying on a Cloud Service 
#
data "external" "extractInfrastructureID" {
  depends_on = [
    null_resource.generate_manifests
  ]

  program = ["bash", "${path.module}/get_install_state.sh" ]

  query = {
      infra_id = var.infra_id
      openshift_install_state_file = var.infra_id != "" ? "" : data.local_file.openshift_install_state_json[0].filename
  }
}

resource "null_resource" "get_auth_config" {
  depends_on = [null_resource.generate_ignition_config]
  provisioner "local-exec" {
    when    = create
    command = "cp ${path.root}/installer-files//temp/auth/* ${path.root}/ "
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.root}/kubeconfig ${path.root}/kubeadmin-password "
  }
}
