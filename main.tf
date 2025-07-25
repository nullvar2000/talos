# create a secrets.yaml file in the state file
resource "talos_machine_secrets" "this" {
  talos_version = local.talos_version
}

### configure control plane #######################################################

data "talos_machine_configuration" "controlplane" {
  cluster_name       = local.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = local.talos_version
  kubernetes_version = local.kubernetes_version
}

resource "talos_machine_configuration_apply" "controlplane" {
  count                       = local.control_plane.deploy ? local.control_plane.node_count : 0

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = format("${local.node_name_prefix}-${local.control_plane.name_indicator}%02d", count.index + 1)
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        network = {
          hostname = format("${local.node_name_prefix}-${local.control_plane.name_indicator}%02d", count.index + 1)
          interfaces = [
            {
              dhcp = false
              deviceSelector = {
                physical = true
              }
              addresses = [
                cidrhost(local.control_plane.ip_range, "${count.index + local.control_plane.ip_start}")
              ]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = local.gateway
                }
              ]
              vip = {
                ip = local.vip_ip
              }
            }
          ]
          nameservers = local.name_servers
        }
        time = {
          disabled = false
          servers = local.ntp_servers
        }
      }
    })
  ]
}

### bootstrap the cluster #######################################################

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]

  count                = local.bootstrap ? 1 : 0

  node                 = cidrhost(local.control_plane.ip_range, local.control_plane.ip_start)
  client_configuration = talos_machine_secrets.this.client_configuration
}

### configure storage nodes #######################################################

data "talos_image_factory_extensions_versions" "storage" {
  talos_version = local.talos_version
  filters = {
    names = local.storage.extensions
  }
}

resource "talos_image_factory_schematic" "storage" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.storage.extensions_info.*.name
        }
      }
    }
  )
}

data "talos_machine_configuration" "storage" {
  cluster_name     = local.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version = local.talos_version
  kubernetes_version = local.kubernetes_version
}

resource "talos_machine_configuration_apply" "storage" {
  count = local.storage.node_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.storage.machine_configuration
  node = cidrhost(local.storage.ip_range, "${count.index + local.storage.ip_start}")
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          diskSelector = { 
            size = "256060514304"
          }
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.storage.id}:${local.talos_version}"
        }
        network = {
          hostname = format("${local.node_name_prefix}-${local.storage.name_indicator}%02d", count.index + 4)
          interfaces = [
            {
              dhcp = false
              deviceSelector = {
                physical = true
              }
              addresses = [
                cidrhost(local.storage.ip_range, "${count.index + local.storage.ip_start}")
              ]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = local.gateway
                }
              ]
            }
          ]
          nameservers = local.name_servers
        }
        time = {
          disabled = false
          servers = local.ntp_servers
        }
        kubelet = {
          extraMounts = [
            {
              destination = "/var/mnt/longhorn"
              type = "bind"
              source = "/var/mnt/longhorn"
              options = [
                "bind",
                "rshared",
                "rw"
              ]
            }
          ]
        }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind = "UserVolumeConfig"
      name = "longhorn"
      provisioning = {
        diskSelector = {
          match = "disk.transport == \"sata\""
        }
        minSize = "512GiB"
        grow = true
      }
      filesystem = {
        type = "xfs"
      } 
    })
  ]

  provisioner "local-exec" {
    command = "kubectl label node talos-s01 node-role.kubernetes.io/storage=storage; kubectl taint node talos-s01 node-role.kubernetes.io/storage:PreferNoSchedule"
  } 
}

### configure worker nodes #######################################################

data "talos_image_factory_extensions_versions" "worker" {
  talos_version = local.talos_version
  filters = {
    names = local.worker.extensions
  }
}

resource "talos_image_factory_schematic" "worker" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.worker.extensions_info.*.name
        }
      }
    }
  )
}

data "talos_machine_configuration" "worker" {
  cluster_name     = local.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version = local.talos_version
  kubernetes_version = local.kubernetes_version
}

resource "talos_machine_configuration_apply" "worker" {
  count = local.worker.node_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node = cidrhost(local.worker.ip_range, "${count.index + local.worker.ip_start}")
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.worker.id}:${local.talos_version}"
        }
        network = {
          hostname = format("${local.node_name_prefix}-${local.worker.name_indicator}%02d", count.index + 1)
          interfaces = [
            {
              dhcp = false
              deviceSelector = {
                physical = true
              }
              addresses = [
                cidrhost(local.worker.ip_range, "${count.index + local.worker.ip_start}")
              ]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = local.gateway
                }
              ]
            }
          ]
          nameservers = local.name_servers
        }
        time = {
          disabled = false
          servers = local.ntp_servers
        }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind = "VolumeConfig"
      name = "EPHEMERAL"
      provisioning = {
        diskSelector = {
          match = "disk.transport == \"sata\""
        }
        minSize = "30GB"
        maxSize = "40GB"
        grow = true
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind = "UserVolumeConfig"
      name = "scratch"
      provisioning = {
        diskSelector = {
          match = "disk.transport == \"sata\""
        }
        minSize = "10GB"
        grow = true
      }
      filesystem = {
        type = "xfs"
      } 
    })
  ]

  provisioner "local-exec" {
    command = "kubectl label node talos-w01 node-role.kubernetes.io/worker=worker"
  }
}

### configure gpu node #######################################################

data "talos_image_factory_extensions_versions" "nvidia" {
  talos_version = local.talos_version
  filters = {
    names = local.nvidia.extensions
  }
}

resource "talos_image_factory_schematic" "nvidia" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.nvidia.extensions_info.*.name
        }
      }
    }
  )
}

data "talos_machine_configuration" "nvidia" {
  cluster_name     = local.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version = local.talos_version
  kubernetes_version = local.kubernetes_version
}

resource "talos_machine_configuration_apply" "nvidia" {
  count = local.nvidia.node_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.nvidia.machine_configuration
  node = cidrhost(local.nvidia.ip_range, "${count.index + local.nvidia.ip_start}")
  
  config_patches = [
    yamlencode({
      machine = {
        kernel = {
          modules = [
            {
              name = "nvidia"
            },
            {
              name = "nvidia_uvm"
            },
            {
              name = "nvidia_drm"
            },
            {
              name = "nvidia_modeset"
            }
          ]
        }
        sysctls = {
          "net.core.bpf_jit_harden" = 1
        }
        files = [
          {
            content = "[plugins]\n  [plugins.\"io.containerd.cri.v1.runtime\"]\n    [plugins.\"io.containerd.cri.v1.runtime\".containerd]\n      default_runtime_name = \"nvidia\""
            path = "/etc/cri/conf.d/20-customization.part"
            op = "create"
          }
        ]
        install = {
          disk = "/dev/sda"
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.nvidia.id}:${local.talos_version}"
        }
        network = {
          hostname = format("${local.node_name_prefix}-${local.nvidia.name_indicator}%02d", count.index + 7)
          interfaces = [
            {
              dhcp = false
              deviceSelector = {
                physical = true
              }
              addresses = [
                cidrhost(local.nvidia.ip_range, "${count.index + local.nvidia.ip_start}")
              ]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = local.gateway
                }
              ]
            }
          ]
          nameservers = local.name_servers
        }
        time = {
          disabled = false
          servers = local.ntp_servers
        }
      }
    })
  ]

  provisioner "local-exec" {
    command = "kubectl label node talos-w07 node-role.kubernetes.io/gpu=nvidia; kubectl label node talos-w07 node-role.kubernetes.io/worker=worker; kubectl taint node talos-w07 node-role.kubernetes.io/gpu:PreferNoSchedule"
  }

}
