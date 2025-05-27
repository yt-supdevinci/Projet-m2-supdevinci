# terraform.tfvars

pm_api_url          = "https://192.168.0.25:8006/api2/json"
pm_api_token_id     = "terraform-prov@pve!terraform"
pm_api_token_secret = "66c36202-b4d1-4c73-ad70-869ffc61a1a7"

instance_count = 5

name = [
  "wazuh-manager",
  "misp-manager", 
  "wazuh-agent-linux",
  "shuffle",
  "dfir-iris"
]

# Un template différent par VM
clone = [
  "template-ubuntu-24-04",    # pour wazuh-manager
  "template-ubuntu-24-04",    # pour misp-manager
  "template-ubuntu-20-04",    # pour wazuh-agent-linux
  "template-ubuntu-20-04",    # pour shuffle
  "template-ubuntu-20-04"     # pour dfir-iris
]

target_node = "pve"

# vmbr0 = LAN / vmbr1 = VM_Network / vmbr2 = DMZ
network_bridge = ["vmbr0", "vmbr0", "vmbr0", "vmbr0", "vmbr0"]

ip = [
  "ip=192.168.0.34/24,gw=192.168.0.1",  # wazuh-manager
  "ip=192.168.0.35/24,gw=192.168.0.1",  # misp-manager
  "ip=192.168.0.36/24,gw=192.168.0.1",  # wazuh-agent-linux
  "ip=192.168.0.37/24,gw=192.168.0.1",  # shuffle
  "ip=192.168.0.33/24,gw=192.168.0.1"   # dfir-iris
]

server_dns = "8.8.8.8"
domain_dns = "pve.sdv"

size = ["150", "50", "20", "50", "20"]  # Tailles en GB pour chaque VM

storage = "local-lvm"
ciuser  = "root"
cipwd   = "test"

ssh_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJqP2NY6govqKB3AivHdDSiEDs0TlKPZE0vetLJxcksWctSSNCS7kxcEzI0Qre/kVcJP6n/ZV1RAOtzNbbVBB/S97624ZvQ3YL1CcvmLBmMnbkD6DahPXotR0EAO/aGyE0fCSqp6Q6v9mNOE5D65eQIxBUoCkRWQzBi9vkzh7C5lb993Bp5j7BAKuLezq9OJhhGNjS5AzR3UcGt8yxe32zcOOdlFNCUvNPNQKeGAgwjDdbw2FRpslmdjypbW4iIYmDlQGLvSsIrLPWxAH8M5TwccIJesmRoQ+nfcgHK2ka01Uivqo2vIhriX+aUKf0wRwk8D7BBN+Y/S/7RQvcW57jAh7GLxGEjB7fgNsvKGbLhaeY7mJgO5X0kPT6C6lXBfm27RhC2XfidmoL1zgYXEmfwS9OoZ35gdZR0jgfeASlB3BJ3CozDBf0WSWxRgYKFqlgu1TsiJcfxSVtbTrczCAx2DcJeNu1eB7g/Ds1gl8V0FcJOCnRSDazotoPp6wPTALiqC0VW+RTXgiYaCl/ua3a6jo14IvGXe87Y9JPrqngGA7a66pRe42EDZZWXu+sS7sF6UN433c/rQPAfbwjfC3u63J2YHKpodPKsICIzNJMTYJsEgrGgewTctVR1jxwRCyIVflUFmAD8r3nusKUee18jfnu1LY3O/ycvnpb1t9ukQ=="