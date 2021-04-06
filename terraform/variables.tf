variable "vsphere_user" {
  type    = string
  default = "Administrator@vsphere.local"
}
variable "vsphere_password" {
  type    = string
  default = "password"
}
variable "vsphere_server" {
  type    = string
  default = "192.168.124.3"
}
variable "vmware_ova_host" {
  type    = string
  default = "192.168.124.2"
}

variable "generationDir" {
  type    = string
  default = "./openshift-install"
}
## Cluster Details

variable "cluster_name" {
  type    = string
  default = "vmware"
}
variable "domain" {
  type    = string
  default = "lab.local"
}
## Cluster VM Counts

variable "master_count" {
  type    = string
  default = "3"
}

variable "worker_count" {
  type    = string
  default = "2"
}

#############################################################################
## Template VM

variable "template_vm_disk_size" {
  type    = string
  default = "32"
}
variable "template_vm_memory_size" {
  type    = string
  default = "24384"
}
variable "template_vm_cpu_count" {
  type    = string
  default = "4"
}

#############################################################################
## Bootstrap VM Configuration

variable "bootstrap_disk_size" {
  type    = string
  default = "32"
}
variable "bootstrap_memory_size" {
  type    = string
  default = "16384"
}
variable "bootstrap_cpu_count" {
  type    = string
  default = "4"
}

variable "bootstrap_vm_network_config" {
  type = map(any)
  default = {
    type      = "static"
    ip        = "192.168.124.20"
    subnet    = "255.255.255.0"
    gateway   = "192.168.124.1"
    interface = "ens192"
    dns       = "192.168.124.235"
    server_id = ""
  }
}

variable "master_cpu_count" {
  type    = string
  default = "4"
}
variable "master_memory_size" {
  type    = string
  default = "16384"
}
variable "master_disk_size" {
  type    = string
  default = "32"
}

variable "worker_cpu_count" {
  type    = string
  default = "4"
}
variable "worker_memory_size" {
  type    = string
  default = "16384"
}
variable "worker_disk_size" {
  type    = string
  default = "32"
}
#### Master Nodes - Network Options
variable "master_network_config" {
  type = map(any)
  default = {
    master_0_type      = "static"
    master_0_ip        = "192.168.124.7"
    master_0_subnet    = "255.255.255.0"
    master_0_gateway   = "192.168.124.1"
    master_0_interface = "ens192"
    dns                = "192.168.124.235"
    master_0_server_id = ""

    master_1_type      = "static"
    master_1_ip        = "192.168.124.8"
    master_1_subnet    = "255.255.255.0"
    master_1_gateway   = "192.168.124.1"
    master_1_interface = "ens192"
    dns                = "192.168.124.235"
    master_1_server_id = ""

    master_2_type      = "static"
    master_2_ip        = "192.168.124.9"
    master_2_subnet    = "255.255.255.0"
    master_2_gateway   = "192.168.124.1"
    master_2_interface = "ens192"
    dns                = "192.168.124.235"
    master_2_server_id = ""
  }
}
#### Worker Nodes - Network Options
variable "worker_network_config" {
  type = map(any)
  default = {
    worker_0_type      = "static"
    worker_0_ip        = "192.168.124.10"
    worker_0_subnet    = "255.255.255.0"
    worker_0_gateway   = "192.168.124.1"
    worker_0_interface = "ens192"
    dns                = "192.168.124.235"
    worker_0_server_id = ""

    worker_1_type      = "static"
    worker_1_ip        = "192.168.124.11"
    worker_1_subnet    = "255.255.255.0"
    worker_1_gateway   = "192.168.124.1"
    worker_1_interface = "ens192"
    dns                = "192.168.124.235"
    worker_1_server_id = ""

    worker_2_type      = "static"
    worker_2_ip        = "192.168.124.12"
    worker_2_subnet    = "255.255.255.0"
    worker_2_gateway   = "192.168.124.1"
    worker_2_interface = "ens192"
    dns                = "192.168.124.235"
    worker_2_server_id = ""
  }
}
