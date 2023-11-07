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
## Access podman remotely

To access podman remotely, it is needed to configure the podman server as described [here](https://github.com/containers/podman/blob/main/docs/tutorials/remote_client.md#enable-the-podman-service-on-the-server-machine)
When done, yu can deploy a podman's pod and configure the [remote client](https://github.com/containers/podman/blob/main/docs/tutorials/remote_client.md#using-the-client) to access it:
```bash
sh-5.2# podman -r system connection add fed37 ssh://<VM_USER>@<IP_ADDRESS_FEDORA37_VM>/run/user/1000/podman/podman.sock

Example:
podman -r system connection add fed37 ssh://fedora@10.131.1.249/run/user/1000/podman/podman.sock

sh-5.2# podman -r system connection list
Name        URI                                                            Identity    Default
fed37       ssh://fedora@10.131.1.249:22/run/user/1000/podman/podman.sock              true
```

## TODO

To be reviewed and to determine if we need them
- Create a `NetworkAttachmentDefinition` resource to access the VM
```bash
kubectl apply -n development -f network-attachment-def.yml
```