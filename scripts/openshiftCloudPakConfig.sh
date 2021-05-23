#!/bin/sh
export ARTIFACTSLOCATION=${1::-1}
export ARTIFACTSTOKEN=\"$2\"
export SUDOUSER=$3
export WORKERNODECOUNT=$4
export NAMESPACE=$5
export APIKEY=$6
export FIPSENABLED=$7

export INSTALLERHOME=/home/$SUDOUSER/.ibm
export OCPTEMPLATES=/home/$SUDOUSER/.openshift/templates

runuser -l $SUDOUSER -c "mkdir -p $INSTALLERHOME"
runuser -l $SUDOUSER -c "mkdir -p $OCPTEMPLATES"

# Root kube config
mkdir -p /root/.kube
cp /home/$SUDOUSER/.kube/config /root/.kube/config

# Create Registry Route
runuser -l $SUDOUSER -c "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"defaultRoute\":true, \"replicas\":$WORKERNODECOUNT}}'"
runuser -l $SUDOUSER -c "sleep 20"
runuser -l $SUDOUSER -c "oc project kube-system"
registryRoute=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}' --kubeconfig /home/$SUDOUSER/.kube/config)
runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/registries.conf <<EOF
unqualified-search-registries = ['registry.access.redhat.com', 'docker.io']
[[registry]]
prefix = \"${registryRoute}\"
insecure = true
blocked = false
location = \"${registryRoute}\"
EOF"

# Machine Configs
insecureRegistryData=$(cat $OCPTEMPLATES/registries.conf | base64 -w 0)
runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/insecure-registry-mc.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 90-worker-container-runtime
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${insecureRegistryData}
        filesystem: root
        mode: 0644
        path: /etc/containers/registries.conf
EOF"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/sysctl-mc.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 98-master-worker-sysctl
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,dm0ubWF4X21hcF9jb3VudCA9IDI2MjE0NAprZXJuZWwuc2VtID0gMjUwIDEwMjQwMDAgMTAwIDQwOTYKa2VybmVsLm1zZ21heCA9IDY1NTM2Cmtlcm5lbC5tc2dtbmIgPSA2NTUzNg==
        filesystem: root
        mode: 0644
        path: /etc/sysctl.conf
EOF"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/limits-mc.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 15-security-limits
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,KiAgICAgICAgICAgICAgIGhhcmQgICAgbm9maWxlICAgICAgICAgNjY1NjAKKiAgICAgICAgICAgICAgIHNvZnQgICAgbm9maWxlICAgICAgICAgNjY1NjA=
        filesystem: root
        mode: 0644
        path: /etc/security/limits.conf
EOF"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/crio-mc.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 90-worker-crio
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,W2NyaW9dCltjcmlvLmFwaV0Kc3RyZWFtX2FkZHJlc3MgPSAiIgpzdHJlYW1fcG9ydCA9ICIxMDAxMCIKW2NyaW8ucnVudGltZV0KZGVmYXVsdF91bGltaXRzID0gWwogICAgIm5vZmlsZT02NTUzNjo2NTUzNiIKXQpjb25tb24gPSAiL3Vzci9saWJleGVjL2NyaW8vY29ubW9uIgpjb25tb25fY2dyb3VwID0gInBvZCIKYXBwYXJtb3JfcHJvZmlsZSA9ICJjcmlvLWRlZmF1bHQiCmNncm91cF9tYW5hZ2VyID0gInN5c3RlbWQiCmhvb2tzX2RpciA9IFsKICAgICIvZXRjL2NvbnRhaW5lcnMvb2NpL2hvb2tzLmQiLApdCnBpZHNfbGltaXQgPSAxMjAwMApbY3Jpby5pbWFnZV0KZ2xvYmFsX2F1dGhfZmlsZSA9ICIvdmFyL2xpYi9rdWJlbGV0L2NvbmZpZy5qc29uIgpwYXVzZV9pbWFnZSA9ICJxdWF5LmlvL29wZW5zaGlmdC1yZWxlYXNlLWRldi9vY3AtdjQuMC1hcnQtZGV2QHNoYTI1NjoyZGMzYmRjYjJiMGJmMWQ2YzZhZTc0OWJlMDE2M2U2ZDdjYTgxM2VjZmJhNWU1ZjVkODg5NzBjNzNhOWQxMmE5IgpwYXVzZV9pbWFnZV9hdXRoX2ZpbGUgPSAiL3Zhci9saWIva3ViZWxldC9jb25maWcuanNvbiIKcGF1c2VfY29tbWFuZCA9ICIvdXNyL2Jpbi9wb2QiCltjcmlvLm5ldHdvcmtdCm5ldHdvcmtfZGlyID0gIi9ldGMva3ViZXJuZXRlcy9jbmkvbmV0LmQvIgpwbHVnaW5fZGlycyA9IFsKICAgICIvdmFyL2xpYi9jbmkvYmluIiwKXQpbY3Jpby5tZXRyaWNzXQplbmFibGVfbWV0cmljcyA9IHRydWUKbWV0cmljc19wb3J0ID0gOTUzNw==
        filesystem: root
        mode: 0644
        path: /etc/crio/crio.conf
EOF"

runuser -l $SUDOUSER -c "cat > $OCPTEMPLATES/chrony-mc.yaml <<EOF
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 90-worker-chrony
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,cG9vbCAyLnJoZWwucG9vbC5udHAub3JnIGlidXJzdApkcmlmdGZpbGUgL3Zhci9saWIvY2hyb255L2RyaWZ0Cm1ha2VzdGVwIDEuMCAzCnJ0Y3N5bmMKbG9nZGlyIC92YXIvbG9nL2Nocm9ueQpyZWZjbG9jayBQSEMgL2Rldi9wdHAwIHBvbGwgMyBkcG9sbCAtMiBvZmZzZXQgMAo=
        filesystem: root
        mode: 0644
        path: /etc/chrony.conf
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 90-master-chrony
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,cG9vbCAyLnJoZWwucG9vbC5udHAub3JnIGlidXJzdApkcmlmdGZpbGUgL3Zhci9saWIvY2hyb255L2RyaWZ0Cm1ha2VzdGVwIDEuMCAzCnJ0Y3N5bmMKbG9nZGlyIC92YXIvbG9nL2Nocm9ueQpyZWZjbG9jayBQSEMgL2Rldi9wdHAwIHBvbGwgMyBkcG9sbCAtMiBvZmZzZXQgMAo=
        filesystem: root
        mode: 0644
        path: /etc/chrony.conf
EOF"

runuser -l $SUDOUSER -c "sudo mv $OCPTEMPLATES/registries.conf /etc/containers/registries.conf"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/insecure-registry-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/sysctl-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/limits-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/crio-mc.yaml"
runuser -l $SUDOUSER -c "oc create -f $OCPTEMPLATES/chrony-mc.yaml"

runuser -l $SUDOUSER -c "echo 'Sleeping for 12mins while MCs apply and the cluster restarts' "
runuser -l $SUDOUSER -c "sleep 12m"

#CPD Config
runuser -l $SUDOUSER -c "wget https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case/ibm-cp-datacore-1.3.3.tgz -O $INSTALLERHOME/ibm-cp-datacore-1.3.3.tgz"
runuser -l $SUDOUSER -c "wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.6.1-2002/cloudctl-linux-amd64.tar.gz -O $INSTALLERHOME/cloudctl-linux-amd64.tar.gz"
runuser -l $SUDOUSER -c "wget https://github.com/IBM/cloud-pak-cli/releases/download/v3.6.1-2002/cloudctl-linux-amd64.tar.gz.sig -O $INSTALLERHOME/cloudctl-linux-amd64.tar.gz.sig"
runuser -l $SUDOUSER -c "(cd $INSTALLERHOME && tar -xf cloudctl-linux-amd64.tar.gz)"
runuser -l $SUDOUSER -c "(cd $INSTALLERHOME && tar -xf ibm-cp-datacore-1.3.3.tgz)"
runuser -l $SUDOUSER -c "chmod +x $INSTALLERHOME/cloudctl-linux-amd64"

# Service Account Token for COD installation
runuser -l $SUDOUSER -c "oc new-project $NAMESPACE"
runuser -l $SUDOUSER -c "oc create serviceaccount cpdtoken"
runuser -l $SUDOUSER -c "oc policy add-role-to-user admin system:serviceaccount:$NAMESPACE:cpdtoken"


#Install operator
export CPD_REGISTRY=cp.icr.io/cp/cpd
export CPD_REGISTRY_USER=cp
export CPD_REGISTRY_PASSWORD=$APIKEY
export OPT_NAMESPACE="cpd-meta-ops"

runuser -l $SUDOUSER -c "oc new-project $OPT_NAMESPACE"
runuser -l $SUDOUSER -c "$INSTALLERHOME/cloudctl-linux-amd64 case launch              \
    --case $INSTALLERHOME/ibm-cp-datacore     \
    --namespace ${OPT_NAMESPACE}              \
    --inventory cpdMetaOperatorSetup          \
    --action install-operator                 \
    --tolerance=1                             \
    --args \"--entitledRegistry ${CPD_REGISTRY} --entitledUser ${CPD_REGISTRY_USER} --entitledPass ${CPD_REGISTRY_PASSWORD}\""

runuser -l $SUDOUSER -c "echo 'Sleeping 7m for operator to install'"
runuser -l $SUDOUSER -c "sleep 7m"
runuser -l $SUDOUSER -c "OP_STATUS=$(oc get pods -n $OPT_NAMESPACE -l name=ibm-cp-data-operator --no-headers --kubeconfig /home/$SUDOUSER/.kube/config | awk '{print $3}')"
runuser -l $SUDOUSER -c "echo OP_STATUS is {$OP_STATUS}"
runuser -l $SUDOUSER -c "if [ $OP_STATUS != 'Running' ]; then echo \"CPD Operator Installation Failed\" ; exit 1 ; fi"
echo "$(date) - ############### Script Complete #############"
