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
export GOVC_RESOURCE_POOL=moncluster/Resources  ####default pool
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

# export WORKER_CPU="16"
# export WORKER_MEMORY="65536"

export WORKER_CPU="4"
export WORKER_MEMORY="16384"

export ocp_net_gw="192.168.124.1"
export ocp_net_mask="255.255.255.0"
export ocp_net_dns="192.168.124.235"
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


wget wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.7/latest/rhcos-vmware.x86_64.ova

govc import.ova -options=coreos.json -name coreostemplate rhcos-vmware.x86_64.ova
govc vm.markastemplate coreostemplate
bootstrap=$(cat openshift-install/bootstrap-append.ign | base64 -w0)
govc vm.change -e="guestinfo.ignition.config.data=${bootstrap}" -vm=${bootstrap_name}
govc vm.change -e="guestinfo.ignition.config.data.encoding=base64" -vm=${bootstrap_name}
govc vm.change -e="disk.EnableUUID=TRUE" -vm=${bootstrap_name}
govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${bootstrap_ip}::${ocp_net_gw}:${ocp_net_mask}:${bootstrap_name}:ens192:off nameserver=${ocp_net_dns}" -vm=${bootstrap_name}
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
# govc vm.change -e="disk.EnableUUID=TRUE" -vm=${worker_name}02.${CLUSTER_DOMAIN}


govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${worker1_ip}::${ocp_net_gw}:${ocp_net_mask}:${worker_name}00.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${worker_name}00.${CLUSTER_DOMAIN}
govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${worker2_ip}::${ocp_net_gw}:${ocp_net_mask}:${worker_name}01.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${worker_name}01.${CLUSTER_DOMAIN}
# govc vm.change -e="guestinfo.afterburn.initrd.network-kargs=ip=${worker3_ip}::${ocp_net_gw}:${ocp_net_mask}:${worker_name}02.${CLUSTER_DOMAIN}:ens192:off nameserver=${ocp_net_dns}" -vm=${worker_name}02.${CLUSTER_DOMAIN}

govc vm.change -c=${WORKER_CPU} -m=${WORKER_MEMORY} -vm=${worker_name}00.${CLUSTER_DOMAIN}
govc vm.change -c=${WORKER_CPU} -m=${WORKER_MEMORY} -vm=${worker_name}01.${CLUSTER_DOMAIN}
govc vm.change -c=${WORKER_CPU} -m=${WORKER_MEMORY} -vm=${worker_name}02.${CLUSTER_DOMAIN}


govc vm.disk.change -vm ${worker_name}00.${CLUSTER_DOMAIN} -size 120GB
govc vm.disk.change -vm ${worker_name}01.${CLUSTER_DOMAIN} -size 120GB
govc vm.disk.change -vm ${worker_name}02.${CLUSTER_DOMAIN} -size 120GB


govc vm.power -on=true bootstrap
govc vm.power -on=true ${master_name}00.${CLUSTER_DOMAIN}
govc vm.power -on=true ${master_name}01.${CLUSTER_DOMAIN}
govc vm.power -on=true ${master_name}02.${CLUSTER_DOMAIN}
govc vm.power -on=true ${worker_name}00.${CLUSTER_DOMAIN}
govc vm.power -on=true ${worker_name}01.${CLUSTER_DOMAIN}
# govc vm.power -on=true ${worker_name}02.${CLUSTER_DOMAIN}



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
