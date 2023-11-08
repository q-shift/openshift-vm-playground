# OpenShift VM Playground

## Prerequisites

- [virtctl](https://docs.openshift.com/container-platform/4.13/virt/virt-using-the-cli-tools.html#installing-virtctl_virt-using-the-cli-tools) client

## Instructions to create a VM and to ssh to it

- Log on to an OCP 4.13 cluster, install the Openshift virtualization operator and create a `HyperConverged` CR using the defaults
- Create or select a project/namespace
```bash
oc new-project development
```
- Create a Kubernetes secret using the public key needed to ssh to the VM
```bash
kubectl create secret generic fedora-ssh-key -n development --from-file=key=~/.ssh/shared_vm_rsa.pub                  
```
- Set a network bridge to allow pods to access the VM within the cluster
```bash
kubectl apply -n development -f network-bridge.yml
```
**NOTE**: Don't create the bridge using the UI as documented [here](https://github.com/rhpds/roadshow_ocpvirt_instructions/blob/summit/workshop/content/06_network_management.adoc) as you will get the following error `0/6 nodes are available: 3 Insufficient devices.kubevirt.io/kvm, 3 Insufficient devices.kubevirt.io/tun, 3 Insufficient devices.kubevirt.io/vhost-net, 3 node(s) didn't match node selector, 6 Insufficient bridge-cni.network.kubevirt.io/br1`. To fix it, remove the annotation: https://bugzilla.redhat.com/show_bug.cgi?id=1727810

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

To access podman remotely, it is needed to expose the daemon host using socat within the Fedora VM
```bash
sh-5.2# socat TCP-LISTEN:2376,reuseaddr,fork,bind=0.0.0.0 UNIX-SOCKET:/var/run/user/1000/podman/podman.sock
```
then from a pod running a docker/podman client, you will be able to access the daemon
```bash
kubectl apply -n development -f podman-pod.yml
kubectl exec -n development podman-client  -it -- /bin/sh
sh-5.2# export DOCKER_HOST=tcp://fedora37:2376
sh-5.2# podman pull hello-world 
Resolved "hello-world" as an alias (/etc/containers/registries.conf.d/000-shortnames.conf)
Trying to pull quay.io/podman/hello:latest...
Getting image source signatures
Copying blob d08b40be6878 done   | 
Copying config e2b3db5d4f done   | 
Writing manifest to image destination
e2b3db5d4fdf670b56dd7138d53b5974f2893a965f7d37486fbb9fcbf5e91d9d
```          

## TODO

To be reviewed and to determine if we need them
- Create a `NetworkAttachmentDefinition` resource to access the VM
```bash
kubectl apply -n development -f network-attachment-def.yml
```