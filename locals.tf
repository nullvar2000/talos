locals {
  cluster_name = "talos-cluster"
  cluster_endpoint = "https://192.168.30.100:6443"
  talos_version = "v1.10.5"
  kubernetes_version = "v1.31.7"
  
  node_name_prefix = "talos"
  
  vip_ip = "192.168.30.100"
  gateway = "192.168.30.1"
  name_servers = [
    "192.168.30.1"
  ]
  ntp_servers = [
    "pool.ntp.org"
  ]

  bootstrap = false

  control_plane = {
    deploy = false
    node_count = 3
    ip_range = "192.168.30.0/24"
    ip_start = 101
    name_indicator = "cp"
  }
  
  storage = {
    deploy = true
    node_count = 1
    ip_range = "192.168.30.0/24"
    ip_start = 114
    name_indicator = "s"
    extensions = [
      "iscsi-tools",
      "util-linux-tools"
    ]
  }

  worker = {
    node_count = 1
    ip_range = "192.168.30.0/24"
    ip_start = 121
    name_indicator = "w"
    extensions = [
      "iscsi-tools",
      "util-linux-tools",
      "i915"
    ]
  }

  nvidia = {
    node_count = 0
    ip_range = "192.168.30.0/24"
    ip_start = 127
    name_indicator = "w"
    extensions = [
      "iscsi-tools",
      "util-linux-tools",
      "nvidia-container-toolkit-production",
      "nonfree-kmod-nvidia-production"
    ]
  }
}
