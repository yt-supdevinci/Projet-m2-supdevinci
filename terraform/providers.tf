terraform {

required_providers {

proxmox = {

source = "Telmate/proxmox"

version = "3.0.1-rc1"

}

}

}

provider "proxmox" {

pm_api_url = var.pm_api_url

pm_api_token_id = var.pm_api_token_id

pm_api_token_secret = var.pm_api_token_secret

pm_tls_insecure = true

pm_log_enable = true

pm_log_file = "terraform-plugin-prox-vm.log"

pm_log_levels = {

_default = "debug"

_capturelog = ""

}

}
