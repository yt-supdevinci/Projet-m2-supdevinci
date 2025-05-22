resource "proxmox_vm_qemu" "proxmox" {

count = var.instance_count

name = element(var.name,count.index)

target_node = var.target_node

clone = var.clone
#cpu

cores = 2

sockets = 4

cpu = "host"

#memory

memory = "8000"

#network

network {

bridge = element(var.network_bridge,count.index)

tag = element(var.tag,count.index)

model = "virtio"

}

ipconfig0 = element(var.ip,count.index)

nameserver = var.server_dns
searchdomain = var.domain_dns
#disk

scsihw = "virtio-scsi-pci"

cloudinit_cdrom_storage = var.storage

disks {

virtio {

virtio0 {

disk {

size = element(var.size, count.index)

storage = var.storage

iothread = true

}

}

}

}

#cloud init config

os_type = "cloud-init"

ciuser = var.ciuser

cipassword = var.cipwd

sshkeys = <<EOF

${var.ssh_key}

EOF

provisioner "remote-exec" {
connection {
type = "ssh"
user = "root"
#password = var.cipwd
host = "192.168.0.34"
private_key = file("/root/.ssh/id_rsa")
timeout = "2m"
}
inline = [
"while ! nc -z 192.168.0.34 22; do echo 'Waiting for SSH...'; sleep 10; done",
"echo 'SSH is up!'"
]
}

}
resource "null_resource" "wait_for_ssh" {
provisioner "local-exec" {
command = <<EOT
echo "⏳ Waiting for SSH on 192.168.0.34..."
while ! nc -z 192.168.0.34 22; do sleep 10; done
echo "✅ SSH is now available!"
EOT
}
depends_on = [proxmox_vm_qemu.proxmox]
}

resource "null_resource" "run_ansible" {
provisioner "local-exec" {
command = <<EOT
if ssh-keygen -F "192.168.0.34"; then
ssh-keygen -f "/root/.ssh/known_hosts" -R "192.168.0.34"
fi
echo "🚀 Lancement du playbook Ansible..."
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ../ansible/wazuh-ansible-OLD/playbooks/inventory ../ansible/wazuh-ansible/wazuh.yml
EOT
  }
  depends_on = [null_resource.wait_for_ssh]
}
