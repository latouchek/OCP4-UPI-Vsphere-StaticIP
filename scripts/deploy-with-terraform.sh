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
wget wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.7/latest/rhcos-vmware.x86_64.ova
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

terraform init
terraform plan
terraform apply -auto-approve
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
