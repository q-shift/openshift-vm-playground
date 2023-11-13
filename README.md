# OpenShift VM Playground

## Prerequisites

- [virtctl](https://docs.openshift.com/container-platform/4.13/virt/virt-using-the-cli-tools.html#installing-virtctl_virt-using-the-cli-tools) client
- [Tekton client](https://tekton.dev/docs/cli/)

## Instructions to create a VM and to ssh to it

- Log on to an OCP 4.13 cluster, install the Openshift virtualization operator 
- Deploy the `HyperConverged` CR to enable the nested virtualization feature:
```bash
kubectl apply -f resources/hyperconverged.yml
```
- Create or select a project/namespace
```bash
oc new-project <NAMESPACE>
```
- Create a Kubernetes secret using your public key needed to ssh to the VM
```bash
kubectl create secret generic fedora-ssh-key -n <NAMESPACE> --from-file=key=~/.ssh/<PUBLIC_KEY_FILE>.pub                  
```
- When done, create a VirtualMachine
```bash
kubectl delete -n <NAMESPACE> vm/fedora38
kubectl apply -n <NAMESPACE> -f resources/vm-fedora38.yml
```
- When the VM is running, you can ssh using the following command (optional)
```bash
virtctl ssh --local-ssh fedora@fedora38
```
## Build a Quarkus application using Tekton

First create the pvc used to git clone and build quarkus
```bash
cd pipelines 
kubectl apply -f setup/persistentvolumeclaim-project-pvc.yaml
```

Next, deploy the pipeline and pipelineRun to build the Quarkus application
```bash
kubectl delete pipelinerun/quarkus-maven-build-run
kubectl delete pipeline/quarkus-maven-build
kubectl delete task/git-clone
kubectl delete task/maven
kubectl delete task/rm-workspace
kubectl delete task/virtualmachine
kubectl delete task/ls-workspace

kubectl apply -f tasks/git-clone.yaml
kubectl apply -f tasks/rm-workspace.yaml
kubectl apply -f tasks/ls-workspace.yaml
kubectl apply -f tasks/maven.yaml
kubectl apply -f tasks/virtualmachine.yaml
kubectl apply -f pipelines/quarkus-maven-build.yaml
kubectl apply -f pipelineruns/quarkus-maven-build-run.yaml
```
You can follow the pipeline execution using the following command:
```bash
tkn pr logs quarkus-maven-build-run -f
```

**NOTE**: If you experiment an issue with the `podman -r run`, you can then modify the `create-remote-container` included within the pipeline `quarkus-maven-build` and set the parameter `debug` to `true` within the PipelineRun `quarkus-maven-build-run`

## End-to-end test

To play with Kubevirt and Tekton and execute an end to end test case where we create a Virtual Machine running podman 
and next deploy a Tekto pipeline able to build a Quarkus application running some Test container(s), execute this command:
```bash
./e2e.sh <VM_NAME> <NAMESPACE> <PUBLIC_KEY_FILE_PATH>
```
where:
- <VM_NAME>: name of the virtual machine and also OS image to download (e.g fedora38 = quay.io/containerdisks/fedora:38)
- <NAMESPACE>: kubernetes namespace where scenario should be deployed and tested
- <PUBLIC_KEY_FILE_PATH>: path to the file containing the public key to be imported within the VM

## Access podman remotely

To access podman remotely, it is needed to expose the daemon host using socat within the Fedora VM
```bash
sh-5.2# socat TCP-LISTEN:2376,reuseaddr,fork,bind=0.0.0.0 unix:/run/user/1000/podman/podman.sock  # rootless for user 1000
sh-5.2# socat TCP-LISTEN:2376,reuseaddr,fork,bind=0.0.0.0 unix:/run/podman/podman.sock            # rootfull
```
then from a pod running a docker/podman client, you will be able to access the daemon
```bash
kubectl apply -n <NAMESPACE> -f resources/podman-pod.yml
kubectl exec -n <NAMESPACE> podman-client  -it -- /bin/sh
sh-5.2# podman -r --url=tcp://<VM_IP>:2376 ps
CONTAINER ID  IMAGE       COMMAND     CREATED     STATUS      PORTS       NAMES

sh-5.2# podman -r --url=tcp://<VM_IP>:2376 images
REPOSITORY  TAG         IMAGE ID    CREATED     SIZE

sh-5.2# podman -r --url=tcp://<VM_IP>:2376 pull hello-world
Resolved "hello-world" as an alias (/etc/containers/registries.conf.d/000-shortnames.conf)
Trying to pull quay.io/podman/hello:latest...
Getting image source signatures
Copying blob sha256:d08b40be68780d583e8c127f10228743e3e1beb520f987c0e32f4ef0c0ce8020
Copying config sha256:e2b3db5d4fdf670b56dd7138d53b5974f2893a965f7d37486fbb9fcbf5e91d9d
Writing manifest to image destination
e2b3db5d4fdf670b56dd7138d53b5974f2893a965f7d37486fbb9fcbf5e91d9d
```

## Issues

The step to setup a network bridge is not needed to allow the pods to access the VM within the cluster as a Kuybernetes Service is required in this case
When we tried to use the `Network Attachment Definition`een faced to the following error: `0/6 nodes are available: 3 Insufficient devices.kubevirt.io/kvm, 3 Insufficient devices.kubevirt.io/tun, 3 Insufficient devices.kubevirt.io/vhost-net, 3 node(s) didn't match node selector, 6 Insufficient bridge-cni.network.kubevirt.io/br1`. 
To fix it, follow the instructions described within this ticket: https://bugzilla.redhat.com/show_bug.cgi?id=1727810

**TIP**: Don't create using ocp 4.13.x the bridge using the UI as documented [here](https://github.com/rhpds/roadshow_ocpvirt_instructions/blob/summit/workshop/content/06_network_management.adoc)e can also create a service using the virtctl client: `virtctl expose vmi fedora38 --name=fedora38 --port=2376 --target-port=2376`