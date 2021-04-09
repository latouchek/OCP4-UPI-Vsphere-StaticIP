
# Automating OCP 4.7 UPI Installation on Vsphere with Static IPs




## Introduction
In this post we will show how to automate an customize an OCP 4.7 UPI installation on Vsphere.
In the first part we will use govc,an open source command-line utility for performing administrative actions on a VMware vCenter or vSphere and in the second part we will deploy the cluster with Terraform.






## Prequisites:
### DNS, Loadbalancer and Webserver

Use the provided templates in files folder to configure the required services
```bash
dnf install -y named httpd haproxy
mkdir -p  /var/www/html/ignition
```

### Download necessary binaries

We need to install govc client, oc client and ocp installer and Terraform. This is how we proceed
```bash
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.7/openshift-client-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-4.7/openshift-install-linux.tar.gz
wget https://github.com/vmware/govmomi/releases/download/v0.24.0/govc_linux_amd64.gz
tar zxvf openshift-client-linux.tar.gz
tar zxvf openshift-install-linux.tar.gz
gunzip govc_linux_amd64.gz
rm -f *gz README.md
mv oc kubectl openshift-install /usr/local/bin/
mv govc_linux_amd64 /usr/local/bin/govc
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/$release/hashicorp.repo
dnf install terraform -y
```


## Part I
## Automating with govc:

### Export variables for govc (modify according to your env)

```bash
export OCP_RELEASE="4.7.4"
export CLUSTER_DOMAIN="vmware.lab.local"
export GOVC_URL='192.168.124.3'
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='vSphere Pass'
export GOVC_INSECURE=1
export GOVC_NETWORK='VM Network'
export VMWARE_SWITCH='DSwitch'
export GOVC_DATASTORE='datastore1'
export GOVC_DATACENTER='Datacenter'
export GOVC_RESOURCE_POOL=yourcluster_name/Resources  ####default pool
export MYPATH=$(pwd)
export HTTP_SERVER="192.168.124.1"
export bootstrap_name="bootstrap"
export bootstrap_ip="192.168.124.20"

export HTTP_SERVER="192.168.124.1"
export master_name="master"
export master1_ip="192.168.124.7"
export master2_ip="192.168.124.8"
export master3_ip="192.168.124.9"

export worker_name="worker"
export worker1_ip="192.168.124.10"
export worker2_ip="192.168.124.11"
export worker3_ip="192.168.124.12"

export MASTER_CPU="4"
export MASTER_MEMORY="16384"   
export WORKER_CPU="4"
export WORKER_MEMORY="16384"

export ocp_net_gw="192.168.124.1"
export ocp_net_mask="255.255.255.0"
export ocp_net_dns="192.168.124.235"

```
### Create ignition files
Modify install-config.yaml according to your needs.
Because bootstrap ignition is too big, it needs to be placed on a webserver and downloaded during the first boot. To achieve that, we create bootstrap-append.ign that points to the right file
 ```bash
 rm -f /var/www/html/ignition/*.ign
 rm -rf ${MYPATH}/openshift-install
 rm -rf ~/.kube
 mkdir ${MYPATH}/openshift-install
 mkdir ~/.kube
 cp install-config.yaml ${MYPATH}/openshift-install/install-config.yaml
 cat > ${MYPATH}/openshift-install/bootstrap-append.ign <<EOF
 {
   "ignition": {
     "config": {
       "merge": [
       {
         "source": "http://${HTTP_SERVER}:8080/ignition/bootstrap.ign"
       }
       ]
     },
     "version": "3.1.0"
   }
 }
 EOF
 openshift-install create ignition-configs --dir  openshift-install --log-level debug
 cp ${MYPATH}/openshift-install/*.ign /var/www/html/ignition/
 chmod o+r /var/www/html/ignition/*.ign
 restorecon -vR /var/www/html/
 cp ${MYPATH}/openshift-install/auth/kubeconfig ~/.kube/config

 ```

 ### Prepare CoreOS template

 Before downloading the ova we create coreos.json to modify Network mapping (Make sure GOVC_NETWORK is properly defined )

 ```bash
cat > coreos.json <<EOF
{
"DiskProvisioning": "flat",
"IPAllocationPolicy": "dhcpPolicy",
"IPProtocol": "IPv4",
"PropertyMapping": [
{
  "Key": "guestinfo.ignition.config.data",
  "Value": ""
},
{
  "Key": "guestinfo.ignition.config.data.encoding",
  "Value": ""
}
],
"NetworkMapping": [
{
  "Name": "VM Network",
  "Network": "${GOVC_NETWORK}"
}
],
"MarkAsTemplate": false,
"PowerOn": false,
"InjectOvfEnv": false,
"WaitForIP": false,
"Name": null
}
EOF
```
We can now download the image, apply the changes, import, tag the resulting VM as template and finaly create the bootsrap VM out of this template

```bash
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.7/latest/rhcos-vmware.x86_64.ova
govc import.ova -options=coreos.json -name coreostemplate rhcos-vmware.x86_64.ova
govc vm.markastemplate coreostemplate
govc vm.clone -vm coreostemplate  -on=false  bootstrap
```
IGN files need to be provided to Vsphere instance through guestinfo.ignition.config.data. We need to encode it in base64 before anything and change the previously created bootstrap VM:
```bash
bootstrap=$(cat openshift-install/append-bootstrap.ign | base64 -w0)
govc vm.change -e="guestinfo.ignition.config.data=${bootstrap}" -vm=${bootstrap_name}
govc vm.change -e="guestinfo.ignition.config.data.encoding=base64" -vm=${bootstrap_name}
govc vm.change -e="disk.EnableUUID=TRUE" -vm=${bootstrap_name}
```
To set Static IP to bootstrap we issue the following command:
```bash
govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${bootstrap_ip}::${ocp_net_gw}:${ocp_net_mask}:${bootstrap_name}:ens192:off nameserver=${ocp_net_dns}" -vm=${bootstrap_name}
```
We are going to repeat those steps for Masters and Workers :
```bash
govc vm.clone -vm coreostemplate  -on=false  ${master_name}00.${CLUSTER_DOMAIN}
govc vm.clone -vm coreostemplate  -on=false  ${master_name}01.${CLUSTER_DOMAIN}
govc vm.clone -vm coreostemplate  -on=false  ${master_name}02.${CLUSTER_DOMAIN}

govc vm.change -c=${MASTER_CPU} -m=${MASTER_MEMORY} -vm=${master_name}00.${CLUSTER_DOMAIN}
govc vm.change -c=${MASTER_CPU} -m=${MASTER_MEMORY} -vm=${master_name}01.${CLUSTER_DOMAIN}
govc vm.change -c=${MASTER_CPU} -m=${MASTER_MEMORY} -vm=${master_name}02.${CLUSTER_DOMAIN}

govc vm.disk.change -vm ${master_name}00.${CLUSTER_DOMAIN} -size 120GB
govc vm.disk.change -vm ${master_name}01.${CLUSTER_DOMAIN} -size 120GB
govc vm.disk.change -vm ${master_name}02.${CLUSTER_DOMAIN} -size 120GB

master=$(cat openshift-install/master.ign | base64 -w0)

govc vm.change -e="guestinfo.ignition.config.data=${master}" -vm=${master_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.ignition.config.data=${master}" -vm=${master_name}01.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.ignition.config.data=${master}" -vm=${master_name}02.${CLUSTER_DOMAIN}

govc vm.change -e="guestinfo.ignition.config.data.encoding=base64" -vm=${master_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.ignition.config.data.encoding=base64" -vm=${master_name}01.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.ignition.config.data.encoding=base64" -vm=${master_name}02.${CLUSTER_DOMAIN}

govc vm.change -e="disk.EnableUUID=TRUE" -vm=${master_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="disk.EnableUUID=TRUE" -vm=${master_name}01.${CLUSTER_DOMAIN}
govc vm.change -e="disk.EnableUUID=TRUE" -vm=${master_name}02.${CLUSTER_DOMAIN}

govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${master1_ip}::${ocp_net_gw}:${ocp_net_mask}:${master_name}00.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${master_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${master2_ip}::${ocp_net_gw}:${ocp_net_mask}:${master_name}01.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${master_name}01.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${master3_ip}::${ocp_net_gw}:${ocp_net_mask}:${master_name}02.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${master_name}02.${CLUSTER_DOMAIN}

worker=$(cat /var/opsh/ocpddc-test/worker.ign | base64 -w0)
govc vm.clone -vm coreostemplate  -on=false  ${worker_name}00.${CLUSTER_DOMAIN}
govc vm.clone -vm coreostemplate  -on=false  ${worker_name}01.${CLUSTER_DOMAIN}
# govc vm.clone -vm coreostemplate  -on=false  ${worker_name}02.${CLUSTER_DOMAIN}

govc vm.change -e="guestinfo.ignition.config.data=${worker}" -vm=${worker_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.ignition.config.data=${worker}" -vm=${worker_name}01.${CLUSTER_DOMAIN}
# govc vm.change -e="guestinfo.ignition.config.data=${worker}" -vm=${worker_name}02.${CLUSTER_DOMAIN}

govc vm.change -e="guestinfo.ignition.config.data.encoding=base64" -vm=${worker_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.ignition.config.data.encoding=base64" -vm=${worker_name}01.${CLUSTER_DOMAIN}
# govc vm.change -e="guestinfo.ignition.config.data.encoding=base64" -vm=${worker_name}02.${CLUSTER_DOMAIN}

govc vm.change -e="disk.EnableUUID=TRUE" -vm=${worker_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="disk.EnableUUID=TRUE" -vm=${worker_name}01.${CLUSTER_DOMAIN}
govc vm.change -e="disk.EnableUUID=TRUE" -vm=${worker_name}02.${CLUSTER_DOMAIN}

govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${worker1_ip}::${ocp_net_gw}:${ocp_net_mask}:${worker_name}00.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${worker_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${worker2_ip}::${ocp_net_gw}:${ocp_net_mask}:${worker_name}01.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${worker_name}01.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${worker3_ip}::${ocp_net_gw}:${ocp_net_mask}:${worker_name}02.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${worker_name}02.${CLUSTER_DOMAIN}

govc vm.change -c=${WORKER_CPU} -m=${WORKER_MEMORY} -vm=${worker_name}00.${CLUSTER_DOMAIN}
govc vm.change -c=${WORKER_CPU} -m=${WORKER_MEMORY} -vm=${worker_name}01.${CLUSTER_DOMAIN}
govc vm.change -c=${WORKER_CPU} -m=${WORKER_MEMORY} -vm=${worker_name}02.${CLUSTER_DOMAIN}

govc vm.disk.change -vm ${worker_name}00.${CLUSTER_DOMAIN} -size 120GB
govc vm.disk.change -vm ${worker_name}01.${CLUSTER_DOMAIN} -size 120GB
govc vm.disk.change -vm ${worker_name}02.${CLUSTER_DOMAIN} -size 120GB
```
### Time to start the nodes:
```bash
govc vm.power -on=true bootstrap
govc vm.power -on=true ${master_name}00.${CLUSTER_DOMAIN}
govc vm.power -on=true ${master_name}01.${CLUSTER_DOMAIN}
govc vm.power -on=true ${master_name}02.${CLUSTER_DOMAIN}
govc vm.power -on=true ${worker_name}00.${CLUSTER_DOMAIN}
govc vm.power -on=true ${worker_name}01.${CLUSTER_DOMAIN}
govc vm.power -on=true ${worker_name}02.${CLUSTER_DOMAIN}
```
### Wait for the installation to complete

```bash
openshift-install --dir=openshift-install wait-for bootstrap-complete
openshift-install --dir=openshift-install wait-for bootstrap-complete > /tmp/bootstrap-test 2>&1
grep safe /tmp/bootstrap-test > /dev/null 2>&1
if [ "$?" -ne 0 ]
then
	echo -e "\n\n\nERROR: Bootstrap did not complete in time!"
	echo "Your environment (CPU or network bandwidth) might be"
	echo "too slow. Continue by hand or execute cleanup.sh and"
	echo "start all over again."
	exit 1
fi
echo -e "\n\n[INFO] Completing the installation and approving workers...\n"
for csr in $(oc -n openshift-machine-api get csr | awk '/Pending/ {print $1}'); do oc adm certificate approve $csr;done
sleep 180

for csr in $(oc -n openshift-machine-api get csr | awk '/Pending/ {print $1}'); do oc adm certificate approve $csr;done

openshift-install --dir=openshift-install wait-for install-complete --log-level debug       

```
## Part II
## Automating with Terraform
With terraform we will create all the objects we need (templates and VMs) in a single piece of code. If we want to scale our cluster we'll just have to modify one variable value and rerun terraform to modify the state of our cluster. Before proceeding, please modify **variables.tf** and **install-config.yaml** according to your needs and place it in the **terraform** folder.
Also we need to export **govc** variables since terraform needs it during the template creation

```bash
export OCP_RELEASE="4.7.4"
export CLUSTER_DOMAIN="vmware.lab.local"
export GOVC_URL='192.168.124.3'
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='password'
export GOVC_INSECURE=1
export GOVC_NETWORK='VM Network'
export VMWARE_SWITCH='DSwitch'
export GOVC_DATASTORE='datastore1'
export GOVC_DATACENTER='Datacenter'
export GOVC_RESOURCE_POOL=[VSPHERE_CLUSTER]/Resources  ####default pool
export MYPATH=$(pwd)
export HTTP_SERVER="192.168.124.1"
```


### Create ignition files


 ```bash
 cd terraform
 rm -f /var/www/html/ignition/*.ign
 rm -rf ${MYPATH}/openshift-install
 rm -rf ~/.kube
 mkdir ${MYPATH}/openshift-install
 mkdir ~/.kube
 cp install-config.yaml ${MYPATH}/openshift-install/install-config.yaml
 cat > ${MYPATH}/openshift-install/bootstrap-append.ign <<EOF
 {
   "ignition": {
     "config": {
       "merge": [
       {
         "source": "http://${HTTP_SERVER}:8080/ignition/bootstrap.ign"
       }
       ]
     },
     "version": "3.1.0"
   }
 }
 EOF
 openshift-install create ignition-configs --dir  openshift-install --log-level debug
 cp ${MYPATH}/openshift-install/*.ign /var/www/html/ignition/
 chmod o+r /var/www/html/ignition/*.ign
 restorecon -vR /var/www/html/
 cp ${MYPATH}/openshift-install/auth/kubeconfig ~/.kube/config

 ```
### Create the cluster
```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### Wait for installation to complete

```bash

openshift-install --dir=openshift-install wait-for bootstrap-complete
openshift-install --dir=openshift-install wait-for bootstrap-complete > /tmp/bootstrap-test 2>&1
grep safe /tmp/bootstrap-test > /dev/null 2>&1
if [ "$?" -ne 0 ]
then
	echo -e "\n\n\nERROR: Bootstrap did not complete in time!"
	echo "Your environment (CPU or network bandwidth) might be"
	echo "too slow. Continue by hand or execute cleanup.sh and"
	echo "start all over again."
	exit 1
fi
echo -e "\n\n[INFO] Completing the installation and approving workers...\n"
for csr in $(oc -n openshift-machine-api get csr | awk '/Pending/ {print $1}'); do oc adm certificate approve $csr;done
sleep 180

for csr in $(oc -n openshift-machine-api get csr | awk '/Pending/ {print $1}'); do oc adm certificate approve $csr;done

openshift-install --dir=openshift-install wait-for install-complete --log-level debug

```
If the installation times out you might need to type the following command again:

```bash
openshift-install --dir=openshift-install wait-for install-complete --log-level debug
```

Result should look like this:

```bash
[root@esxi-bastion terraform]# openshift-install --dir=openshift-install wait-for install-complete --log-level debug
DEBUG OpenShift Installer 4.7.4                    
.
.
.
DEBUG Route found in openshift-console namespace: console
DEBUG OpenShift console route is admitted          
INFO Install complete!                            
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/root/terraform-vsphere-ignitiontest/openshift-install/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.vmware.lab.local
INFO Login to the console with user: "kubeadmin", and password: "TkwHE-GWu5U-rAEsA-FrgqQ"
```
### How does it work?

Just like with govc we need to create a template and clone it to create Bootstrap, Masters and Workers in that order and inject ignitions and network setup.

  * We create a template to clone from as shown by the terraform block bellow.

  The **local-exec** **provisioner** is needed to actualy stop the created VM so it can be used as a **template**.

  In this case we use **local_ovf_path** and thus have to download the ova beforehand but **remote_ovf_url** works as well for a more dynamic approach.

  Terraform  **ovf_network_map** support capabilities allows us to set  the right Network for this Template.
```terraform
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
```

  * Let's take a look at the **Masters** definition block (Some lines were removed for better visibility)

 Workers nodes specs are described in **variables.tf** and we use a **'Count'** loop to create the Nodes.

 To feed **ignition** to our VMs we create a data source read from local file  **master.ign**

 ```terraform
data "local_file" "master_vm_ignition" {
  filename   = "${var.generationDir}/master.ign"
}
```
We defines the  **masterVMs** **vsphere_virtual_machine**  resource that depends on the **bootstrapVM** resource  and we use the coreOS template created previously with the **clone** block.
```terraform
resource "vsphere_virtual_machine" "masterVMs" {
  depends_on = [vsphere_virtual_machine.bootstrapVM]
  count      = var.master_count

  name             = "${var.cluster_name}-master0${count.index}"
.
.
.
.

  clone {
    template_uuid = data.vsphere_virtual_machine.coreostemplate.id
  }
  ```
  To inject ignition data and metadata into the VM we need to use the **extra_config block**. Unfortunately and as stated in Fedora  CoreOS Documentation, **vApp** Property does not work in this scenario. Syntax is very similar to what was done with govc.
```terraform
  extra_config = {
    "guestinfo.ignition.config.data"           = base64encode(data.local_file.master_vm_ignition.content)
    "guestinfo.ignition.config.data.encoding"  = "base64"
    "guestinfo.hostname"                       = "${var.cluster_name}-master${count.index}"
    "guestinfo.afterburn.initrd.network-kargs" = lookup(var.master_network_config, "master_${count.index}_type") != "dhcp" ? "ip=${lookup(var.master_network_config, "master_${count.index}_ip")}:${lookup(var.master_network_config, "master_${count.index}_server_id")}:${lookup(var.master_network_config, "master_${count.index}_gateway")}:${lookup(var.master_network_config, "master_${count.index}_subnet")}:${var.cluster_name}-master${count.index}:${lookup(var.master_network_config, "master_${count.index}_interface")}:off nameserver=${lookup(var.bootstrap_vm_network_config, "dns")}" : "ip=::::${var.cluster_name}-master${count.index}:ens192:on"
  }
}
```

* Workers nodes are created the exact same way except we changed the resource we want to use with **depends_on** meta-argument. That way we make sure Workers built after Masters.
```terraform
resource "vsphere_virtual_machine" "workerVMs" {
  depends_on = [vsphere_virtual_machine.masterVMs]
  .
  .
  .  
}
```


### Thank you for reading
* References
  * https://github.com/luisarizmendi/ocp-vsphere-staticip
  * https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs
  * https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-vmware/
  * https://www.virtuallyghetto.com/2020/06/full-ova-ovf-property-support-coming-to-terraform-provider-for-vsphere.html
