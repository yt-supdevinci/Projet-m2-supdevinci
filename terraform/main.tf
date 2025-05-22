resource "proxmox_vm_qemu" "proxmox" {
  count       = var.instance_count
  name        = element(var.name, count.index)
  target_node = var.target_node
  clone       = element(var.clone, count.index)
  
  # cpu
  cores   = 2
  sockets = 4
  cpu     = "host"
  
  # memory
  memory = "8000"
  
  # network
  network {
    bridge = element(var.network_bridge, count.index)
    model  = "virtio"
  }
  
  ipconfig0    = element(var.ip, count.index)
  nameserver   = var.server_dns
  searchdomain = var.domain_dns
  
  # disk
  scsihw                 = "virtio-scsi-pci"
  cloudinit_cdrom_storage = var.storage
  
  disks {
    virtio {
      virtio0 {
        disk {
          size      = element(var.size, count.index)
          storage   = var.storage
          iothread  = true
        }
      }
    }
  }
  
  # cloud init config
  os_type    = "cloud-init"
  ciuser     = var.ciuser
  cipassword = var.cipwd
  sshkeys    = <<EOF
${var.ssh_key}
EOF

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("/root/.ssh/id_rsa")
      host        = "10.50.131.30"
      timeout     = "5m"
    }
    
    inline = [
      # Attendre que le verrou apt se libère
      "while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do echo 'Waiting for APT lock...'; sleep 10; done",
      # Mettre à jour la liste des paquets
      "apt-get update -y && apt-get install -y netcat-openbsd || echo 'Netcat déjà installé'",
      # Vérifier que netcat est bien installé
      "command -v nc || (echo 'Netcat installation failed!' && exit 1)",
      # Attendre que SSH soit disponible
      "while ! nc -z 10.50.131.30 22; do echo 'Waiting for SSH...'; sleep 10; done",
      "echo 'SSH is up!'"
    ]
  }
}

resource "null_resource" "wait_for_ssh" {
  provisioner "local-exec" {
    command = <<EOT
echo "⏳ Waiting for SSH on 10.50.131.30..."
while ! nc -z 10.50.131.30 22; do sleep 10; done
echo "✅ SSH is now available!"
EOT
  }
  
  depends_on = [proxmox_vm_qemu.proxmox]
}

resource "null_resource" "run_ansible" {
  provisioner "local-exec" {
    command = <<EOT
if ssh-keygen -F "10.50.131.30"; then
  ssh-keygen -f "/root/.ssh/known_hosts" -R "10.50.131.30"
fi
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ../ansible/wazuh-ansible/playbooks/inventory ../ansible/wazuh-ansible/playbooks/wazuh-single.yml
EOT
  }
  
  depends_on = [null_resource.wait_for_ssh]
}