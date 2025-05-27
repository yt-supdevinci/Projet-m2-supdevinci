resource "proxmox_vm_qemu" "proxmox" {
  count = var.instance_count

  name        = element(var.name, count.index)
  target_node = var.target_node
  clone       = element(var.clone, count.index)

  # CPU
  cores   = 2
  sockets = 4
  cpu     = "host"

  # Memory
  memory = 8000

  # Network
  network {
    bridge = element(var.network_bridge, count.index)
    model  = "virtio"
  }

  ipconfig0    = element(var.ip, count.index)
  nameserver   = var.server_dns
  searchdomain = var.domain_dns

  # Disk
  scsihw                  = "virtio-scsi-pci"
  cloudinit_cdrom_storage = var.storage

  disks {
    virtio {
      virtio0 {
        disk {
          size     = element(var.size, count.index)
          storage  = var.storage
          iothread = true
        }
      }
    }
  }

  # Cloud init config
  os_type    = "cloud-init"
  ciuser     = var.ciuser
  cipassword = var.cipwd
  sshkeys    = <<EOF
${var.ssh_key}
EOF

}