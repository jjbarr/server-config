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

variable "pb_api" {}
variable "do_token" {}
variable "pb_api_secret" {}

provider "digitalocean" {
  token = var.do_token
}

provider "porkbun" {
  api_key        = var.pb_api
  secret_api_key = var.pb_api_secret
}

data "digitalocean_image" "nixos" {
  name = "nixos-do"
  source = "user"
}

resource "digitalocean_project" "my_servers" {
  name = "project"
  description = "My personal resources."
  environment = "Production"
  resources = [
    digitalocean_droplet.anubis.urn
  ]
}


resource "digitalocean_droplet" "anubis" {
  region = "nyc1"
  name = "anubis"
  size = "s-1vcpu-1gb"
  backups = true
  backup_policy {
    plan = "weekly"
    weekday = "SUN"
    hour = 8
  }
  # nixos
  image = data.digitalocean_image.nixos.id
  ssh_keys = ["74:6f:4c:0c:16:fd:ee:0b:d8:a1:92:cd:52:be:16:78"]
}

resource "porkbun_dns_record" "anubis" {
  domain = "bahamut.monster"
  priority = 0
  name = "anubis"
  type = "A"
  content = digitalocean_droplet.anubis.ipv4_address
  ttl = 600
}
