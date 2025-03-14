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

provider "digitalocean" {
  token = var.do_token
}

provider "porkbun" {
  api_key        = var.pb_api
  secret_api_key = var.pb_api_secret
}

locals {
  hosts = {
    
  }
}

resource "digitalocean_project" "my_servers" {
  name = "project"
  description = "My personal resources."
  environment = "Production"
  resources = [
    digitalocean_droplet.server.urn
  ]
}

resource "digitalocean_ssh_key" "uruk" {
  name = "sshkey"
  public_key = file("~/.ssh/id_ed25519.pub")
}


resource "digitalocean_droplet" "server" {
  region = "nyc1"
  name = local.domain_root
  size = "s-1vcpu-1gb"
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
