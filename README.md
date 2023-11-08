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
kubectl apply -n development -f resources/network-bridge.yml
```
**NOTE**: Don't create the bridge using the UI as documented [here](https://github.com/rhpds/roadshow_ocpvirt_instructions/blob/summit/workshop/content/06_network_management.adoc) as you will get the following error `0/6 nodes are available: 3 Insufficient devices.kubevirt.io/kvm, 3 Insufficient devices.kubevirt.io/tun, 3 Insufficient devices.kubevirt.io/vhost-net, 3 node(s) didn't match node selector, 6 Insufficient bridge-cni.network.kubevirt.io/br1`. To fix it, remove the annotation: https://bugzilla.redhat.com/show_bug.cgi?id=1727810

TODO: Instructions to be reviewed as the bridge is not needed but instead a kubernetes service that we can create using the [command below](https://kubevirt.io/user-guide/virtual_machines/service_objects/#service-objects)
```bash
virtctl expose vmi fedora37 --name=fedora37 --port=2376 --target-port=2376
```
which corresponds to the following yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: fedora37
  namespace: development
spec:
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - port: 2376
    protocol: TCP
    targetPort: 2376
  selector:
    kubevirt.io/domain: fedora37
    kubevirt.io/size: small
  sessionAffinity: None
  type: ClusterIP
```
- When done, deploy a VirtualMachine within the namespace `development`
```bash
kubectl delete -n development vm/fedora37
kubectl apply -n development -f resources/vm-fedora.yml
```
- When the VM is running, you can ssh using the following command
```bash
virtctl ssh --local-ssh fedora@fedora37
```
## Access podman remotely

To access podman remotely, it is needed to expose the daemon host using socat within the Fedora VM
```bash
sh-5.2# socat TCP-LISTEN:2376,reuseaddr,fork,bind=0.0.0.0 unix:/run/user/1000/podman/podman.sock
```
then from a pod running a docker/podman client, you will be able to access the daemon
```bash
kubectl apply -n development -f podman-pod.yml
kubectl exec -n development podman-client  -it -- /bin/sh
sh-5.2# podman -r --url=tcp://fedora37.development.svc.cluster.local:2376 ps
CONTAINER ID  IMAGE       COMMAND     CREATED     STATUS      PORTS       NAMES

sh-5.2# podman -r --url=tcp://fedora37.development.svc.cluster.local:2376 images
REPOSITORY  TAG         IMAGE ID    CREATED     SIZE

sh-5.2# podman -r --url=tcp://fedora37.development.svc.cluster.local:2376 pull hello-world
Resolved "hello-world" as an alias (/etc/containers/registries.conf.d/000-shortnames.conf)
Trying to pull quay.io/podman/hello:latest...
Getting image source signatures
Copying blob sha256:d08b40be68780d583e8c127f10228743e3e1beb520f987c0e32f4ef0c0ce8020
Copying config sha256:e2b3db5d4fdf670b56dd7138d53b5974f2893a965f7d37486fbb9fcbf5e91d9d
Writing manifest to image destination
e2b3db5d4fdf670b56dd7138d53b5974f2893a965f7d37486fbb9fcbf5e91d9d
```          

## TODO

To be reviewed and to determine if we need them
- Create a `NetworkAttachmentDefinition` resource to access the VM
```bash
kubectl apply -n development -f network-attachment-def.yml
```