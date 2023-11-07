# OpenShift VM Playground

## Prerequisites

- [virtctl](https://docs.openshift.com/container-platform/4.13/virt/virt-using-the-cli-tools.html#installing-virtctl_virt-using-the-cli-tools) client

## Instructions to create a VM and to ssh to it

- Log on to an OCP 4.13 cluster and install the Openshift virtualization operator
- Create or select a project/namespace
```bash
oc new-project development
```
- Create a Kubernetes secret using the public key needed to ssh to the VM
```bash
kubectl create secret generic fedora-ssh-key -n development --from-file=key=~/.ssh/shared_vm_rsa.pub                  
```
- When done, deploy a VirtualMachine within the namespace `development`
```bash
kubectl delete -n development vm/fedora37
kubectl apply -n development -f vm-fedora.yml
```
- When the VM is running, you can ssh using the following command
```bash
virtctl ssh --local-ssh fedora@fedora37
```

## TODO

To be reviewed and to determine if we need them
- Create a `NetworkAttachmentDefinition` resource to access the VM
```bash
kubectl apply -n development -f network-attachment-def.yml
```