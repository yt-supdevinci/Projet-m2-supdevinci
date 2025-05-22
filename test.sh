#!/bin/bash

# Script d'automatisation Proxmox + Terraform + Ansible
# Auteur: Script automatisé
# Version: 1.0

set -e  # Arrêter le script en cas d'erreur

# Variables
DEBIAN_TEMPLATE_ID=499
UBUNTU_TEMPLATE_ID=500
DEBIAN_ISO_URL="https://cloud.debian.org/images/cloud/bookworm/20240211-1654/debian-12-genericcloud-amd64-20240211-1654.qcow2"
UBUNTU_ISO_URL="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
ISO_DIR="/var/lib/vz/template/iso"
GITHUB_REPO="https://github.com/votre-repo/terraform-ansible-proxmox.git"  # À modifier
WORK_DIR="/opt/terraform-proxmox"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage avec couleurs
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Vérifier si on est sur Proxmox
    if ! command -v qm &> /dev/null; then
        log_error "qm command not found. Ce script doit être exécuté sur un serveur Proxmox."
        exit 1
    fi
    
    # Vérifier si terraform est installé
    if ! command -v terraform &> /dev/null; then
        log_warning "Terraform n'est pas installé. Installation en cours..."
        install_terraform
    fi
    
    # Vérifier si git est installé
    if ! command -v git &> /dev/null; then
        log_warning "Git n'est pas installé. Installation en cours..."
        apt-get update && apt-get install -y git
    fi
    
    # Vérifier si wget est installé
    if ! command -v wget &> /dev/null; then
        log_warning "Wget n'est pas installé. Installation en cours..."
        apt-get update && apt-get install -y wget
    fi
    
    log_success "Prérequis vérifiés"
}

# Installation de Terraform
install_terraform() {
    log_info "Installation de Terraform..."
    
    # Télécharger et installer Terraform
    cd /tmp
    wget https://releases.hashicorp.com/terraform/1.7.4/terraform_1.7.4_linux_amd64.zip
    apt-get update && apt-get install -y unzip
    unzip terraform_1.7.4_linux_amd64.zip
    mv terraform /usr/local/bin/
    chmod +x /usr/local/bin/terraform
    
    log_success "Terraform installé avec succès"
}

# Création du template Debian 12
create_debian_template() {
    log_info "Création du template Debian 12..."
    
    # Vérifier si le template existe déjà
    if qm status $DEBIAN_TEMPLATE_ID &> /dev/null; then
        log_warning "Template Debian 12 (ID: $DEBIAN_TEMPLATE_ID) existe déjà. Suppression..."
        qm stop $DEBIAN_TEMPLATE_ID 2>/dev/null || true
        qm destroy $DEBIAN_TEMPLATE_ID
    fi
    
    # Aller dans le répertoire des ISOs
    cd $ISO_DIR
    
    # Télécharger l'image Debian 12 si elle n'existe pas
    if [ ! -f "debian-12-genericcloud-amd64-20240211-1654.qcow2" ]; then
        log_info "Téléchargement de l'image Debian 12..."
        wget $DEBIAN_ISO_URL
    else
        log_info "Image Debian 12 déjà présente"
    fi
    
    # Créer la VM
    log_info "Création de la VM Debian 12..."
    qm create $DEBIAN_TEMPLATE_ID --name template-debian-12 --cores 2 --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci
    
    # Importer le disque
    log_info "Import du disque Debian 12..."
    qm set $DEBIAN_TEMPLATE_ID --virtio0 local-lvm:0,import-from=$ISO_DIR/debian-12-genericcloud-amd64-20240211-1654.qcow2
    
    # Configurer cloud-init
    log_info "Configuration cloud-init pour Debian 12..."
    qm set $DEBIAN_TEMPLATE_ID --ide2 local-lvm:cloudinit
    qm set $DEBIAN_TEMPLATE_ID --boot order=virtio0
    qm set $DEBIAN_TEMPLATE_ID --serial0 socket --vga serial0
    
    # Convertir en template
    log_info "Conversion en template..."
    qm template $DEBIAN_TEMPLATE_ID
    
    log_success "Template Debian 12 créé avec succès (ID: $DEBIAN_TEMPLATE_ID)"
}

# Création du template Ubuntu 24.04
create_ubuntu_template() {
    log_info "Création du template Ubuntu 24.04..."
    
    # Vérifier si le template existe déjà
    if qm status $UBUNTU_TEMPLATE_ID &> /dev/null; then
        log_warning "Template Ubuntu 24.04 (ID: $UBUNTU_TEMPLATE_ID) existe déjà. Suppression..."
        qm stop $UBUNTU_TEMPLATE_ID 2>/dev/null || true
        qm destroy $UBUNTU_TEMPLATE_ID
    fi
    
    # Aller dans le répertoire des ISOs
    cd $ISO_DIR
    
    # Télécharger l'image Ubuntu 24.04 si elle n'existe pas
    if [ ! -f "ubuntu-24.04-server-cloudimg-amd64.img" ]; then
        log_info "Téléchargement de l'image Ubuntu 24.04..."
        wget $UBUNTU_ISO_URL
    else
        log_info "Image Ubuntu 24.04 déjà présente"
    fi
    
    # Créer la VM
    log_info "Création de la VM Ubuntu 24.04..."
    qm create $UBUNTU_TEMPLATE_ID --name template-ubuntu-2404 --cores 2 --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci
    
    # Importer le disque
    log_info "Import du disque Ubuntu 24.04..."
    qm set $UBUNTU_TEMPLATE_ID --virtio0 local-lvm:0,import-from=$ISO_DIR/ubuntu-24.04-server-cloudimg-amd64.img
    
    # Configurer cloud-init
    log_info "Configuration cloud-init pour Ubuntu 24.04..."
    qm set $UBUNTU_TEMPLATE_ID --ide2 local-lvm:cloudinit
    qm set $UBUNTU_TEMPLATE_ID --boot order=virtio0
    qm set $UBUNTU_TEMPLATE_ID --serial0 socket --vga serial0
    
    # Convertir en template
    log_info "Conversion en template..."
    qm template $UBUNTU_TEMPLATE_ID
    
    log_success "Template Ubuntu 24.04 créé avec succès (ID: $UBUNTU_TEMPLATE_ID)"
}

# Téléchargement du repository GitHub
download_terraform_ansible() {
    log_info "Téléchargement du repository Terraform/Ansible..."
    
    # Créer le répertoire de travail
    if [ -d "$WORK_DIR" ]; then
        log_warning "Répertoire $WORK_DIR existe déjà. Suppression..."
        rm -rf $WORK_DIR
    fi
    
    mkdir -p $WORK_DIR
    cd $WORK_DIR
    
    # Cloner le repository
    log_info "Clonage du repository..."
    git clone $GITHUB_REPO .
    
    log_success "Repository téléchargé dans $WORK_DIR"
}

# Configuration de Terraform
setup_terraform() {
    log_info "Configuration de Terraform..."
    
    cd $WORK_DIR
    
    # Initialiser Terraform
    if [ -d "terraform" ]; then
        cd terraform
        log_info "Initialisation de Terraform..."
        terraform init
        
        # Créer un fichier terraform.tfvars d'exemple si il n'existe pas
        if [ ! -f "terraform.tfvars" ]; then
            log_info "Création du fichier terraform.tfvars d'exemple..."
            cat > terraform.tfvars << EOF
# Configuration Proxmox
pm_api_url = "https://your-proxmox-server:8006/api2/json"
pm_api_token_id = "your-token-id"
pm_api_token_secret = "your-token-secret"

# Configuration des VMs
target_node = "your-node-name"
instance_count = 1
clone = ["template-debian-12"]
name = ["vm-test"]
network_bridge = ["vmbr0"]
ip = ["10.0.0.100/24"]
server_dns = "8.8.8.8"
domain_dns = "local"
size = ["20G"]
storage = "local-lvm"
ciuser = "admin"
cipwd = "password"
ssh_key = "your-ssh-public-key"
EOF
            log_warning "Fichier terraform.tfvars créé. Veuillez le modifier avec vos paramètres."
        fi
        
        log_success "Terraform configuré"
    else
        log_error "Répertoire terraform non trouvé dans le repository"
    fi
}

# Installation d'Ansible si nécessaire
install_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        log_info "Installation d'Ansible..."
        apt-get update
        apt-get install -y ansible
        log_success "Ansible installé"
    else
        log_info "Ansible déjà installé"
    fi
}

# Fonction principale de déploiement
deploy_infrastructure() {
    log_info "Déploiement de l'infrastructure..."
    
    cd $WORK_DIR/terraform
    
    # Planifier le déploiement
    log_info "Planification Terraform..."
    terraform plan
    
    read -p "Voulez-vous appliquer le plan Terraform ? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Application du plan Terraform..."
        terraform apply -auto-approve
        log_success "Infrastructure déployée avec succès"
    else
        log_info "Déploiement annulé par l'utilisateur"
    fi
}

# Affichage du menu principal
show_menu() {
    echo
    echo "=================================="
    echo "  Automatisation Proxmox/Terraform"
    echo "=================================="
    echo "1. Vérifier les prérequis"
    echo "2. Créer les templates (Debian 12 + Ubuntu 24.04)"
    echo "3. Télécharger le repository GitHub"
    echo "4. Configurer Terraform"
    echo "5. Installer Ansible"
    echo "6. Déployer l'infrastructure"
    echo "7. Tout faire automatiquement"
    echo "8. Quitter"
    echo "=================================="
}

# Menu interactif
interactive_menu() {
    while true; do
        show_menu
        read -p "Choisissez une option (1-8): " choice
        
        case $choice in
            1)
                check_prerequisites
                ;;
            2)
                create_debian_template
                create_ubuntu_template
                ;;
            3)
                download_terraform_ansible
                ;;
            4)
                setup_terraform
                ;;
            5)
                install_ansible
                ;;
            6)
                deploy_infrastructure
                ;;
            7)
                log_info "Exécution complète du script..."
                check_prerequisites
                create_debian_template
                create_ubuntu_template
                download_terraform_ansible
                setup_terraform
                install_ansible
                log_success "Configuration terminée. Modifiez terraform.tfvars puis relancez pour déployer."
                ;;
            8)
                log_info "Au revoir!"
                exit 0
                ;;
            *)
                log_error "Option invalide. Veuillez choisir entre 1 and 8."
                ;;
        esac
        
        echo
        read -p "Appuyez sur Entrée pour continuer..."
    done
}

# Point d'entrée principal
main() {
    log_info "Démarrage du script d'automatisation Proxmox/Terraform/Ansible"
    
    # Vérifier les droits root
    if [ "$EUID" -ne 0 ]; then
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    # Vérifier les arguments
    if [ "$1" == "--auto" ]; then
        log_info "Mode automatique activé"
        check_prerequisites
        create_debian_template
        create_ubuntu_template
        download_terraform_ansible
        setup_terraform
        install_ansible
        log_success "Configuration automatique terminée!"
    else
        interactive_menu
    fi
}

# Gestion des signaux
trap 'log_error "Script interrompu"; exit 1' INT TERM

# Exécuter le script principal
main "$@"
