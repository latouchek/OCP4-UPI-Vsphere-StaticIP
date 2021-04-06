
 provider "vsphere" {
  user           = "Administrator@vsphere.local"
  password       = "password"
  vsphere_server = "192.168.124.3"
  allow_unverified_ssl = true
}

# Data Sources
data "vsphere_datacenter" "dc" {
  name = "Datacenter"
}
data "vsphere_resource_pool" "pool" {
  # If you haven't resource pool, put "Resources" after cluster name
  name          = "moncluster/Resources"
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_datastore" "datastore" {
  name          = "datastore1"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "moncluster"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "VM Network"
  #name          = ""
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}
data "vsphere_host" "host" {
  name          = var.vmware_ova_host
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_virtual_machine" "coreostemplate" {
  depends_on    = [vsphere_virtual_machine.coreostemplate]
  name          = "coreostemplate"
  datacenter_id = data.vsphere_datacenter.dc.id
}

 # ####Masters#####
 resource "vsphere_virtual_machine" "coreostemplate" {
   name             = "coreostemplate"
   resource_pool_id = data.vsphere_resource_pool.pool.id
   datastore_id     = data.vsphere_datastore.datastore.id
   datacenter_id    = data.vsphere_datacenter.dc.id
   host_system_id   = data.vsphere_host.host.id
   num_cpus = 2
   memory   = 4096
   guest_id = "coreos64Guest"
   wait_for_guest_net_timeout  = 0
   wait_for_guest_ip_timeout   = 0
   wait_for_guest_net_routable = false
   enable_disk_uuid  = true
   network_interface {
     network_id = data.vsphere_network.network.id
   }
   ovf_deploy {
     #remote_ovf_url       = "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.7/latest/rhcos-vmware.x86_64.ova"
     local_ovf_path       = "rhcos-vmware.x86_64.ova"
     disk_provisioning    = "thin"
     ovf_network_map = {
       "VM Network" = data.vsphere_network.network.id
   }
  }
  provisioner "local-exec" {
    command = "govc vm.power -off=true coreostemplate && sleep 10"

    environment = {
      GOVC_URL      = var.vsphere_server
      GOVC_USERNAME = var.vsphere_user
      GOVC_PASSWORD = var.vsphere_password
      GOVC_INSECURE = "true"
    }
  }
 }
data "local_file" "bootstrap_vm_ignition" {
  filename   = "${var.generationDir}/bootstrap-append.ign"
}
resource "vsphere_virtual_machine" "bootstrapVM" {
  name             = "${var.cluster_name}-bootstrap"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus         = var.bootstrap_cpu_count
  memory           = var.bootstrap_memory_size
  guest_id         = "coreos64Guest"
  enable_disk_uuid = "true"

  wait_for_guest_net_timeout  = 0
  wait_for_guest_net_routable = false

  scsi_type = data.vsphere_virtual_machine.coreostemplate.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.coreostemplate.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.bootstrap_disk_size
    eagerly_scrub    = data.vsphere_virtual_machine.coreostemplate.disks.0.eagerly_scrub
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.coreostemplate.id
  }

  extra_config = {
    "guestinfo.ignition.config.data"           = base64encode(data.local_file.bootstrap_vm_ignition.content)
    "guestinfo.ignition.config.data.encoding"  = "base64"
    "guestinfo.hostname"                       = "${var.cluster_name}-bootstrap"
    "guestinfo.afterburn.initrd.network-kargs" = lookup(var.bootstrap_vm_network_config, "type") != "dhcp" ? "ip=${lookup(var.bootstrap_vm_network_config, "ip")}:${lookup(var.bootstrap_vm_network_config, "server_id")}:${lookup(var.bootstrap_vm_network_config, "gateway")}:${lookup(var.bootstrap_vm_network_config, "subnet")}:${var.cluster_name}-bootstrap:${lookup(var.bootstrap_vm_network_config, "interface")}:off nameserver=${lookup(var.bootstrap_vm_network_config, "dns")}" : "ip=::::${var.cluster_name}-bootstrap:ens192:on"
  }
}
####Masters###
data "local_file" "master_vm_ignition" {
  filename   = "${var.generationDir}/master.ign"
}
resource "vsphere_virtual_machine" "masterVMs" {
  depends_on = [data.vsphere_virtual_machine.coreostemplate]
  count      = var.master_count

  name             = "${var.cluster_name}-master0${count.index}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus         = var.master_cpu_count
  memory           = var.master_memory_size
  guest_id         = "coreos64Guest"
  enable_disk_uuid = "true"

  wait_for_guest_net_timeout  = 0
  wait_for_guest_net_routable = false

  scsi_type = data.vsphere_virtual_machine.coreostemplate.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.coreostemplate.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.master_disk_size
    eagerly_scrub    = data.vsphere_virtual_machine.coreostemplate.disks.0.eagerly_scrub
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.coreostemplate.id
  }

  extra_config = {
    "guestinfo.ignition.config.data"           = base64encode(data.local_file.master_vm_ignition.content)
    "guestinfo.ignition.config.data.encoding"  = "base64"
    "guestinfo.hostname"                       = "${var.cluster_name}-master${count.index}"
    "guestinfo.afterburn.initrd.network-kargs" = lookup(var.master_network_config, "master_${count.index}_type") != "dhcp" ? "ip=${lookup(var.master_network_config, "master_${count.index}_ip")}:${lookup(var.master_network_config, "master_${count.index}_server_id")}:${lookup(var.master_network_config, "master_${count.index}_gateway")}:${lookup(var.master_network_config, "master_${count.index}_subnet")}:${var.cluster_name}-master${count.index}:${lookup(var.master_network_config, "master_${count.index}_interface")}:off nameserver=${lookup(var.bootstrap_vm_network_config, "dns")}" : "ip=::::${var.cluster_name}-master${count.index}:ens192:on"
  }
}


####Workers###
data "local_file" "worker_vm_ignition" {
  filename   = "${var.generationDir}/worker.ign"
}
resource "vsphere_virtual_machine" "workerVMs" {
  depends_on = [data.vsphere_virtual_machine.coreostemplate]
  count      = var.worker_count

  name             = "${var.cluster_name}-worker0${count.index}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus         = var.worker_cpu_count
  memory           = var.worker_memory_size
  guest_id         = "coreos64Guest"
  enable_disk_uuid = "true"

  wait_for_guest_net_timeout  = 0
  wait_for_guest_net_routable = false

  scsi_type = data.vsphere_virtual_machine.coreostemplate.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.coreostemplate.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.worker_disk_size
    eagerly_scrub    = data.vsphere_virtual_machine.coreostemplate.disks.0.eagerly_scrub
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.coreostemplate.id
  }

  extra_config = {
    "guestinfo.ignition.config.data"           = base64encode(data.local_file.worker_vm_ignition.content)
    "guestinfo.ignition.config.data.encoding"  = "base64"
    "guestinfo.hostname"                       = "${var.cluster_name}-worker${count.index}"
    "guestinfo.afterburn.initrd.network-kargs" = lookup(var.worker_network_config, "worker_${count.index}_type") != "dhcp" ? "ip=${lookup(var.worker_network_config, "worker_${count.index}_ip")}:${lookup(var.worker_network_config, "worker_${count.index}_server_id")}:${lookup(var.worker_network_config, "worker_${count.index}_gateway")}:${lookup(var.worker_network_config, "worker_${count.index}_subnet")}:${var.cluster_name}-worker${count.index}:${lookup(var.worker_network_config, "worker_${count.index}_interface")}:off nameserver=${lookup(var.bootstrap_vm_network_config, "dns")}" : "ip=::::${var.cluster_name}-worker${count.index}:ens192:on"
  }
}
