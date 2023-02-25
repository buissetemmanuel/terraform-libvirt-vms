variable "hostname" {
  type    = list(string)
  default = ["server02","server03","server04","server05"]
}
variable "domain" { default = "local.ch" }
variable "memoryMB" { default = 1024*4 }
variable "cpu" { default = 2 }
variable "disk_size_root_partition" { default = 21474836480 }
variable "disk_size_storage_partition" { default = 107374182400 }

resource "libvirt_pool" "servers_pool" {
  name = "servers_pool"
  type = "dir"
  path = "/usr/local/share/servers_pool"
}

resource "libvirt_volume" "os_name" {
  name   = "fedora-cloud-36"
  pool   = libvirt_pool.servers_pool.name
  source = pathexpand("/mnt/d/redhat/img/fedora-cloud/Fedora-Cloud-Base-36-1.5.x86_64.qcow2")
}

resource "libvirt_volume" "servers" {
  count          = length(var.hostname)
  name           = "${var.hostname[count.index]}"
  pool           = libvirt_pool.servers_pool.name
  base_volume_id = libvirt_volume.os_name.id
  size           = var.disk_size_root_partition
  format         = "qcow2"
}

resource "libvirt_volume" "servers-raw" {
  name   = "${var.hostname[count.index]}-raw"
  pool   = libvirt_pool.servers_pool.name
  size   = var.disk_size_storage_partition
  format = "qcow2"
  count  = length(var.hostname)
}

data "template_file" "user_data" {
  template = file("${path.module}/cloudinit/user_data.cfg")
  vars = {
    hostname = element(var.hostname, count.index)
    fqdn     = "${var.hostname[count.index]}.${var.domain}"
  }
  count = length(var.hostname)
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "${var.hostname[count.index]}-commoninit.iso"
  pool           = libvirt_pool.servers_pool.name
  user_data      = data.template_file.user_data[count.index].rendered
  count          = length(var.hostname)
}

resource "libvirt_network" "servers_network" {
  autostart = true
  name = "servers_network"
  mode = "bridge"
  bridge = "br0"
  dns {
    enabled = true
    local_only = false
    forwarders {
      address = "8.8.8.8"
    }
  }
  dhcp {
    enabled = true
  }
}

resource "libvirt_domain" "servers" {
  count      = length(var.hostname)
  name       = "${var.hostname[count.index]}"
  memory     = var.memoryMB
  vcpu       = var.cpu
  autostart  = true
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.commoninit[count.index].id

  network_interface {
    network_name = libvirt_network.servers_network.name
  }

  disk {
    volume_id = libvirt_volume.servers[count.index].id
  }

  disk {
    volume_id = libvirt_volume.servers-raw[count.index].id
  }

  graphics {
    listen_type = "none"
  }
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
}
