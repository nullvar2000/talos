# .kubeconfig file
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = cidrhost(local.control_plane.ip_range, local.control_plane.ip_start)
}

resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "outputs/kubeconfig"
}

#.talosconfig file 
data "talos_client_configuration" "this" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [local.cluster_endpoint]
  nodes                = [cidrhost(local.control_plane.ip_range, local.control_plane.ip_start)]
}

resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "outputs/talosconfig"
}

# resource "local_file" "control_plane_configuration" {
#   content  = talos_machine_configuration_apply.controlplane[0].machine_configuration
#   filename = "outputs/control_plane_configuration"
# }

resource "local_file" "storage_configuration" {
  content  = talos_machine_configuration_apply.storage[0].machine_configuration
  filename = "outputs/storage_configuration.yaml"
}

resource "local_file" "worker_configuration" {
  content  = talos_machine_configuration_apply.worker[0].machine_configuration
  filename = "outputs/worker_configuration.yaml"
}

# resource "local_file" "nvidia_configuration" {
#   depends_on = [
#     talos_machine_configuration_apply.nvidia
#   ]

#   content  = talos_machine_configuration_apply.nvidia[0].machine_configuration
#   filename = "outputs/nvidia_configuration.yaml"
# }
