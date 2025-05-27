#!/bin/bash

# Script de déploiement SOC - Proxmox + Terraform + Ansible
# Intègre les templates Debian 12 et Ubuntu 24.04
# Version: 1.0

set -e

# ================================
# CONFIGURATION GLOBALE
# ================================

# Variables des templates
UBUNTU_20_04_TEMPLATE_ID=499
UBUNTU_24_04_TEMPLATE_ID=500
UBUNTU_20_04_IMAGE_URL="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
UBUNTU_24_04_IMAGE_URL="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"

ISO_DIR="/var/lib/vz/template/iso"
STORAGE="local-lvm"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"

# Couleurs pour la sortie
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ================================
# FONCTIONS UTILITAIRES
# ================================

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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# ================================
# VÉRIFICATION DES PRÉREQUIS
# ================================

check_prerequisites() {
    log_step "Vérification des prérequis système..."
    
    if [ "$EUID" -ne 0 ]; then
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    if ! command -v qm &> /dev/null; then
        log_error "Ce script doit être exécuté sur un serveur Proxmox VE"
        exit 1
    fi
    
    # Vérifier si Terraform est installé
    if ! command -v terraform &> /dev/null; then
        log_warning "Terraform n'est pas installé. Installation en cours..."
        install_terraform
    else
        log_success "Terraform est déjà installé"
    fi
    
    # Vérifier si Ansible est installé
    if ! command -v ansible-playbook &> /dev/null; then
        log_warning "Ansible n'est pas installé. Installation en cours..."
        install_ansible
    else
        log_success "Ansible est déjà installé"
    fi
    
    log_success "Prérequis vérifiés"
}

# ================================
# INSTALLATION DES OUTILS
# ================================

install_terraform() {
    log_info "Installation de Terraform..."
    cd /tmp
    local terraform_version="1.9.8"
    wget -q "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip"
    unzip -q "terraform_${terraform_version}_linux_amd64.zip"
    mv terraform /usr/local/bin/
    chmod +x /usr/local/bin/terraform
    rm -f "terraform_${terraform_version}_linux_amd64.zip"
    log_success "Terraform installé"
}

install_ansible() {
    log_info "Installation d'Ansible..."
    apt-get update -qq
    apt-get install -y software-properties-common
    apt-add-repository --yes --update ppa:ansible/ansible
    apt-get install -y ansible
    log_success "Ansible installé"
}

# ================================
# CRÉATION DES TEMPLATES
# ================================

create_ubuntu_20_04_template() {
    log_step "Création du template Ubuntu 20.04..."
    
    if qm status $UBUNTU_20_04_TEMPLATE_ID &> /dev/null; then
        log_warning "Template Ubuntu 20.04 (ID: $UBUNTU_20_04_TEMPLATE_ID) existe déjà. Suppression..."
        qm stop $UBUNTU_20_04_TEMPLATE_ID 2>/dev/null || true
        sleep 2
        qm destroy $UBUNTU_20_04_TEMPLATE_ID
    fi
    
    mkdir -p "$ISO_DIR"
    cd "$ISO_DIR"
    
    local ubuntu_image="focal-server-cloudimg-amd64.img"
    if [ ! -f "$ubuntu_image" ]; then
        log_info "Téléchargement de l'image Ubuntu 20.04..."
        wget -O "$ubuntu_image" "$UBUNTU_20_04_IMAGE_URL"
    fi
    
    log_info "Création de la VM template Ubuntu 20.04..."
    qm create $UBUNTU_20_04_TEMPLATE_ID \
        --name "template-ubuntu-20-04" \
        --cores 1 \
        --memory 1024 \
        --net0 "virtio,bridge=vmbr0" \
        --scsihw virtio-scsi-pci \
        --ostype l26 \
        --bios ovmf \
        --machine q35 \
        --cpu host
    
    log_info "Import du disque principal..."
    qm set $UBUNTU_20_04_TEMPLATE_ID --virtio0 "$STORAGE:0,import-from=$ISO_DIR/$ubuntu_image,discard=on"
    
    log_info "Redimensionnement du disque..."
    qm resize $UBUNTU_20_04_TEMPLATE_ID virtio0 20G
    
    log_info "Configuration Cloud-Init..."
    # Ajouter le disque Cloud-Init
    qm set $UBUNTU_20_04_TEMPLATE_ID --ide2 "$STORAGE:cloudinit"
    
    # Configuration du boot avec Cloud-Init
    qm set $UBUNTU_20_04_TEMPLATE_ID --boot order=virtio0
    qm set $UBUNTU_20_04_TEMPLATE_ID --bootdisk virtio0
    
    # Configuration série et agent
    qm set $UBUNTU_20_04_TEMPLATE_ID --serial0 socket --vga serial0
    
    # Configuration spécifique Ubuntu
    qm set $UBUNTU_20_04_TEMPLATE_ID --agent 1
    
    log_info "Conversion en template..."
    qm template $UBUNTU_20_04_TEMPLATE_ID
    
    # Retourner au répertoire du script
    cd "$SCRIPT_DIR"
    
    log_success "Template Ubuntu 20.04 créé (ID: $UBUNTU_20_04_TEMPLATE_ID)"
}

create_ubuntu_24_04_template() {
    log_step "Création du template Ubuntu 24.04..."
    
    if qm status $UBUNTU_24_04_TEMPLATE_ID &> /dev/null; then
        log_warning "Template Ubuntu 24.04 (ID: $UBUNTU_24_04_TEMPLATE_ID) existe déjà. Suppression..."
        qm stop $UBUNTU_24_04_TEMPLATE_ID 2>/dev/null || true
        sleep 2
        qm destroy $UBUNTU_24_04_TEMPLATE_ID
    fi
    
    mkdir -p "$ISO_DIR"
    cd "$ISO_DIR"
    
    local ubuntu_image="ubuntu-24.04-server-cloudimg-amd64.img"
    if [ ! -f "$ubuntu_image" ]; then
        log_info "Téléchargement de l'image Ubuntu 24.04..."
        wget -O "$ubuntu_image" "$UBUNTU_24_04_IMAGE_URL"
    fi
    
    log_info "Création de la VM template Ubuntu 24.04..."
    qm create $UBUNTU_24_04_TEMPLATE_ID \
        --name "template-ubuntu-24-04" \
        --cores 1 \
        --memory 1024 \
        --net0 "virtio,bridge=vmbr0" \
        --scsihw virtio-scsi-pci \
        --ostype l26 \
        --bios ovmf \
        --machine q35 \
        --cpu host
    
    log_info "Import du disque principal..."
    qm set $UBUNTU_24_04_TEMPLATE_ID --virtio0 "$STORAGE:0,import-from=$ISO_DIR/$ubuntu_image,discard=on"
    
    log_info "Redimensionnement du disque..."
    qm resize $UBUNTU_24_04_TEMPLATE_ID virtio0 20G
    
    log_info "Configuration Cloud-Init..."
    # Ajouter le disque Cloud-Init
    qm set $UBUNTU_24_04_TEMPLATE_ID --ide2 "$STORAGE:cloudinit"
    
    # Configuration du boot avec Cloud-Init
    qm set $UBUNTU_24_04_TEMPLATE_ID --boot order=virtio0
    qm set $UBUNTU_24_04_TEMPLATE_ID --bootdisk virtio0
    
    # Configuration série et agent
    qm set $UBUNTU_24_04_TEMPLATE_ID --serial0 socket --vga serial0
    
    # Configuration spécifique Ubuntu
    qm set $UBUNTU_24_04_TEMPLATE_ID --agent 1
    
    log_info "Conversion en template..."
    qm template $UBUNTU_24_04_TEMPLATE_ID
    
    # Retourner au répertoire du script
    cd "$SCRIPT_DIR"
    
    log_success "Template Ubuntu 24.04 créé (ID: $UBUNTU_24_04_TEMPLATE_ID)"
}

# ================================
# DÉPLOIEMENT TERRAFORM
# ================================

deploy_terraform() {
    log_step "Déploiement de l'infrastructure avec Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Vérifier la présence des fichiers Terraform
    if [ ! -f "main.tf" ] || [ ! -f "providers.tf" ] || [ ! -f "variables.tf" ]; then
        log_error "Fichiers Terraform manquants. Vérifiez le contenu du répertoire $TERRAFORM_DIR"
        log_info "Les fichiers trouvés dans $TERRAFORM_DIR sont:"
        ls -la
        cd - > /dev/null
        return 1
    fi
    
    # Vérifier la présence du fichier de variables
    if [ ! -f "terraform.tfvars" ] && [ -f "variables.tfvars" ]; then
        log_info "Utilisation du fichier variables.tfvars au lieu de terraform.tfvars"
        ln -sf variables.tfvars terraform.tfvars
    elif [ ! -f "terraform.tfvars" ] && [ ! -f "variables.tfvars" ]; then
        log_error "Fichier de variables (terraform.tfvars ou variables.tfvars) non trouvé."
        cd - > /dev/null
        return 1
    fi
    
    log_info "Initialisation de Terraform..."
    terraform init
    
    log_info "Validation de la configuration..."
    terraform validate
    
    log_info "Planification du déploiement..."
    if [ -f "variables.tfvars" ]; then
        terraform plan -var-file="variables.tfvars"
    else
        terraform plan
    fi
    
    echo
    read -p "Voulez-vous déployer l'infrastructure ? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Déploiement en cours..."
        
        if [ -f "variables.tfvars" ]; then
            terraform apply -auto-approve -var-file="variables.tfvars"
        else
            terraform apply -auto-approve
        fi
        
        log_info "Attente du démarrage des VMs..."
        sleep 30
        
        log_success "Infrastructure déployée avec succès"
        terraform output
        cd - > /dev/null
        return 0
    else
        log_warning "Déploiement annulé"
        cd - > /dev/null
        return 1
    fi
}

# ================================
# DÉPLOIEMENT ANSIBLE
# ================================

deploy_ansible() {
    log_step "Configuration des machines avec Ansible..."
    
    # Déploiement de Wazuh
    log_info "Déploiement de Wazuh..."
    cd "$ANSIBLE_DIR"
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i wazuh/inventory.ini wazuh/wazuh-new.yml
    local wazuh_status=$?
    if [ $wazuh_status -ne 0 ]; then
        log_error "Erreur lors du déploiement de Wazuh (code d'erreur: $wazuh_status)"
        log_warning "Poursuite du déploiement avec les autres composants..."
    else
        log_success "Déploiement de Wazuh réussi"
    fi
    
    # Déploiement de MISP
    log_info "Déploiement de MISP..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i misp/inventory.ini misp/misp_updated.yml
    local misp_status=$?
    if [ $misp_status -ne 0 ]; then
        log_error "Erreur lors du déploiement de MISP (code d'erreur: $misp_status)"
        log_warning "Poursuite du déploiement avec les autres composants..."
    else
        log_success "Déploiement de MISP réussi"
    fi
    
    # Déploiement de SOAR (Shuffle et DFIR-IRIS)
    log_info "Déploiement de SOAR (Shuffle et DFIR-IRIS)..."
    log_warning "Vérification de la connectivité réseau vers GitHub..."
    if ping -c 2 github.com > /dev/null 2>&1; then
        log_info "Connectivité vers GitHub OK, poursuite du déploiement SOAR..."
    else
        log_warning "Impossible de joindre GitHub. Vérifiez votre connexion Internet et les paramètres réseau."
        log_warning "Tentative de déploiement quand même..."
    fi
    
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i soar/inventories/prod/hosts soar/playbooks/deploy_shuffle_iris.yml
    local soar_status=$?
    if [ $soar_status -ne 0 ]; then
        log_error "Erreur lors du déploiement de SOAR (code d'erreur: $soar_status)"
        log_warning "Poursuite du déploiement avec les autres composants..."
    else
        log_success "Déploiement de SOAR réussi"
    fi
    
    # Déploiement de Suricata
    log_info "Déploiement de Suricata..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i suricata-ansible/hosts.ini suricata-ansible/suricata_setup.yml
    local suricata_status=$?
    if [ $suricata_status -ne 0 ]; then
        log_error "Erreur lors du déploiement de Suricata (code d'erreur: $suricata_status)"
        log_warning "Poursuite du déploiement avec les autres composants..."
    else
        log_success "Déploiement de Suricata réussi"
    fi
    
    # Intégration MISP-Wazuh
    log_info "Configuration de l'intégration MISP-Wazuh..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i misp/inventory.ini misp/misp-wazuh-integration2.yml
    local integration_status=$?
    if [ $integration_status -ne 0 ]; then
        log_error "Erreur lors de la configuration de l'intégration MISP-Wazuh (code d'erreur: $integration_status)"
    else
        log_success "Configuration de l'intégration MISP-Wazuh réussie"
    fi
    
    # Vérification finale
    if [ $wazuh_status -eq 0 ] && [ $misp_status -eq 0 ] && [ $soar_status -eq 0 ] && [ $suricata_status -eq 0 ] && [ $integration_status -eq 0 ]; then
        log_success "Tous les composants ont été déployés avec succès"
        cd - > /dev/null
        return 0
    else
        log_warning "Certains composants n'ont pas été déployés correctement. Vérifiez les logs pour plus de détails."
        cd - > /dev/null
        return 1
    fi
}


# ================================
# NETTOYAGE
# ================================

cleanup_environment() {
    log_step "Nettoyage de l'environnement..."
    
    echo
    read -p "⚠️  Confirmer la destruction de l'infrastructure ? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$TERRAFORM_DIR"
        log_info "Destruction de l'infrastructure..."
        terraform destroy -var-file="variables.tfvars" -auto-approve
        
        if qm status $UBUNTU_24_04_TEMPLATE_ID &> /dev/null; then
            log_info "Suppression du template Ubuntu 24.04..."
            qm destroy $UBUNTU_24_04_TEMPLATE_ID
        fi
        
        if qm status $UBUNTU_20_04_TEMPLATE_ID &> /dev/null; then
            log_info "Suppression du template Ubuntu 20.04..."
            qm destroy $UBUNTU_20_04_TEMPLATE_ID
        fi
        
        log_success "Environnement nettoyé"
        cd - > /dev/null
    fi
}

# ================================
# DÉPLOIEMENT COMPLET
# ================================

full_deployment() {
    log_step "🚀 DÉPLOIEMENT COMPLET DU SOC"
    
    check_prerequisites
    
    create_ubuntu_24_04_template
    create_ubuntu_20_04_template
    
    if deploy_terraform; then
        deploy_ansible
        if [ $? -eq 0 ]; then
            log_success "Déploiement complet terminé avec succès"
        else
            log_error "Le déploiement a échoué lors de l'étape Ansible"
            exit 1
        fi
    else
        log_error "Le déploiement a échoué lors de l'étape Terraform"
        exit 1
    fi
}

# ================================
# MENU PRINCIPAL
# ================================

show_menu() {
    echo
    echo "=================================================================="
    echo "                    DÉPLOYEUR SOC PERSONNALISÉ"
    echo "=================================================================="
    echo "1. 🔍 Vérifier les prérequis"
    echo "2. 📦 Créer le template Debian"
    echo "3. 📦 Créer le template Ubuntu"
    echo "4. 🚀 Exécuter le déploiement Terraform uniquement"
    echo "5. 🔧 Exécuter le déploiement Ansible uniquement"
    echo "6. 🏗️  Déploiement complet automatique"
    echo "7. 🧹 Nettoyer l'environnement"
    echo "8. ❌ Quitter"
    echo "=================================================================="
}

interactive_menu() {
    while true; do
        show_menu
        read -p "Choisissez une option (1-8): " choice
        
        case $choice in
            1) check_prerequisites ;;
            2) create_debian_template ;;
            3) create_ubuntu_template ;;
            4) deploy_terraform ;;
            5) deploy_ansible ;;
            6) full_deployment ;;
            7) cleanup_environment ;;
            8)
                log_info "Au revoir!"
                exit 0
                ;;
            *)
                log_error "Option invalide"
                ;;
        esac
        
        echo
        read -p "Appuyez sur Entrée pour continuer..." -r
    done
}

# ================================
# FONCTION PRINCIPALE
# ================================

main() {
    echo "=================================================================="
    echo "                    SOC DEPLOYMENT SCRIPT v1.0"
    echo "=================================================================="
    echo "Déploiement automatisé de l'infrastructure SOC"
    echo "=================================================================="
    
    case "${1:-}" in
        --check)
            check_prerequisites
            ;;
        --ubuntu20.04)
            check_prerequisites
            create_ubuntu_20_04_template
            ;;
        --ubuntu24.04)
            check_prerequisites
            create_ubuntu_24_04_template
            ;;
        --terraform)
            deploy_terraform
            ;;
        --ansible)
            deploy_ansible
            ;;
        --full)
            full_deployment
            ;;
        --cleanup)
            cleanup_environment
            ;;
        --help|-h)
            echo "Usage: $0 [option]"
            echo "  --check        Vérifier les prérequis"
            echo "  --debian       Créer le template Debian"
            echo "  --ubuntu       Créer le template Ubuntu"
            echo "  --terraform    Exécuter uniquement Terraform"
            echo "  --ansible      Exécuter uniquement Ansible"
            echo "  --full         Déploiement complet"
            echo "  --cleanup      Nettoyer l'environnement"
            echo "  --help         Afficher l'aide"
            ;;
        "")
            interactive_menu
            ;;
        *)
            log_error "Option inconnue: $1"
            exit 1
            ;;
    esac
}

# Vérification des droits
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Gestion des signaux
trap 'log_warning "Script interrompu"; exit 130' INT TERM

# Démarrage
main "$@"