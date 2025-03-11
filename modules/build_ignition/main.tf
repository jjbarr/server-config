terraform {
  required_providers {
    ignition = {
      source = "community-terraform-providers/ignition"
      version = "2.4.1"
    }
  }
}

locals {
  home = "/home/core"
}

data "ignition_file" "linger" {
  path = "/var/lib/systemd/linger/core"
  mode = 420 //it's actually 0644 but we don't have octal literals siiigh
  content {
    content = ""
  }
}

data "ignition_file" "unprivileged_ports" {
  path = "/etc/sysctl.d/90-unprivileged_ports.conf"
  content {
    content = <<-EOF
      net.ipv4.ip_unprivileged_port_start = 80
      EOF
  }
}

data "ignition_file" "acme" {
  path = "${local.home}/acme.json"
  uid = 1000
  mode = 384 //600
  content {
    content = ""
  }
}

data "ignition_config" "ignition" {
  links = [data.ignition_link.auto_update.rendered]
  directories = [data.ignition_directory.publicfolder.rendered]
  files = [
    data.ignition_file.linger.rendered,
    data.ignition_file.unprivileged_ports.rendered,
    data.ignition_file.acme.rendered,
  ]
}

output "rendered_configuration" {
  value = data.ignition_config.ignition.rendered
}
