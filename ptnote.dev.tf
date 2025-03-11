terraform {
  required_providers {
    porkbun = {
      source = "kyswtn/porkbun"
      version = "0.1.3"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.49.1"
    }
  }
}

variable domain_root {}
variable do_token {}
variable pb_api {}
variable pb_api_secret {}

locals {
  domain_root = var.domain_root
  subdomains = ["", "www", "social"]
}

provider "digitalocean" {
  token = var.do_token
}

provider "porkbun" {
  api_key        = var.pb_api
  secret_api_key = var.pb_api_secret
}

resource "digitalocean_project" "ptnote" {
  name = "ptnote"
  description = "My personal domain and associated resources."
  environment = "Production"
  resources = [
    digitalocean_droplet.server.urn
  ]
}

resource "digitalocean_ssh_key" "uruk" {
  name = "sshkey"
  // this is public information anyways so I'll just put it here.
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "digitalocean_custom_image" "coreos" {
  name = "coreos"
  url = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/41.20250215.3.0/x86_64/fedora-coreos-41.20250215.3.0-digitalocean.x86_64.qcow2.gz"
  regions = ["nyc1"]
}

module "build_ignition" {
  source = "./modules/build_ignition"
}

resource "digitalocean_droplet" "server" {
  region = "nyc1"
  name = local.domain_root
  size = "s-1vcpu-1gb"
  image = digitalocean_custom_image.coreos.id
  backups = true
  backup_policy {
    plan = "weekly"
    weekday = "SUN"
    hour = 8
  }
  ssh_keys = [digitalocean_ssh_key.uruk.fingerprint]
  user_data = module.build_ignition.rendered_configuration
}

resource "digitalocean_firewall" "firewall" {
  name = "server-firewall"
  droplet_ids = [digitalocean_droplet.server.id]
  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol = "tcp"
    port_range = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol = "udp"
    port_range = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol = "tcp"
    port_range = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol = "udp"
    port_range = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    port_range = "1-65535"
    protocol = "tcp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    port_range = "1-65535"
    protocol = "udp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "porkbun_dns_record" "ipv4" {
  for_each = toset(local.subdomains)
  domain = local.domain_root
  priority = 0
  name = each.key
  type = "A"
  content = digitalocean_droplet.server.ipv4_address
  ttl = 600
}
