# Variables
variable "uninstall_agent" {
  description = "Set to true to uninstall the Wazuh agent"
  type        = bool
  default     = false
}

variable "target_host" {
  description = "Adresse IP ou hostname de la machine cible"
  type        = string
}

variable "ssh_user" {
  description = "Utilisateur SSH pour la connexion à la machine cible"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé privée SSH"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "wazuh_manager_ip" {
  description = "Adresse IP du serveur Wazuh Manager"
  type        = string
  default     = "192.168.0.34"
}

variable "wazuh_agent_name" {
  description = "Nom de l'agent Wazuh"
  type        = string
  default     = "agent-linux-test"
}

variable "wazuh_agent_group" {
  description = "Groupe de l'agent Wazuh"
  type        = string
  default     = "default"
}

# Ressource null_resource pour exécuter la commande
resource "null_resource" "install_wazuh_agent" {
  # Déclencheurs pour forcer la re-exécution si les variables changent
  triggers = {
    target_host        = var.target_host
    wazuh_manager_ip   = var.wazuh_manager_ip
    wazuh_agent_name   = var.wazuh_agent_name
    wazuh_agent_group  = var.wazuh_agent_group
  }

  # Provisioner pour exécuter les commandes sur la machine distante
  provisioner "remote-exec" {
    inline = [
      "wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.12.0-1_amd64.deb",
      "sudo WAZUH_MANAGER='${var.wazuh_manager_ip}' WAZUH_AGENT_GROUP='${var.wazuh_agent_group}' WAZUH_AGENT_NAME='${var.wazuh_agent_name}' dpkg -i ./wazuh-agent_4.12.0-1_amd64.deb",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable wazuh-agent",
      "sudo systemctl start wazuh-agent",
      "rm -f ./wazuh-agent_4.12.0-1_amd64.deb"
    ]

    connection {
      type        = "ssh"
      host        = var.target_host
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
    }
  }
}

# Ressource séparée pour la désinstallation de l'agent
resource "null_resource" "uninstall_wazuh_agent" {
  count = var.uninstall_agent ? 1 : 0

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl stop wazuh-agent || true",
      "sudo systemctl disable wazuh-agent || true", 
      "sudo dpkg -r wazuh-agent || true",
      "sudo rm -rf /var/ossec || true"
    ]

    connection {
      type        = "ssh"
      host        = var.target_host
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
    }
  }
}

# Outputs pour confirmation
output "installation_summary" {
  value = {
    target_host       = var.target_host
    wazuh_manager_ip  = var.wazuh_manager_ip
    wazuh_agent_name  = var.wazuh_agent_name
    wazuh_agent_group = var.wazuh_agent_group
    message          = "Agent Wazuh installé avec succès sur ${var.target_host}"
  }
  depends_on = [null_resource.install_wazuh_agent]
}