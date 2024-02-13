<p align="center">
    <a href="https://github.com/iocanel/openshift-vm-playground/graphs/contributors" alt="Contributors">
        <img src="https://img.shields.io/github/contributors/iocanel/openshift-vm-playground"/></a>
    <a href="https://github.com/iocanel/openshift-vm-playground/pulse" alt="Activity">
        <img src="https://img.shields.io/github/commit-activity/m/iocanel/openshift-vm-playground"/></a>
    <a href="https://github.com/iocanel/openshift-vm-playground/actions/workflows/kubevirt-podman-remote-quarkus-helloworld.yaml" alt="Build Status">
        <img src="https://github.com/iocanel/openshift-vm-playground/actions/workflows/kubevirt-podman-remote-quarkus-helloworld.yaml/badge.svg"></a>
</p>

# OpenShift VM Playground

Table of Contents
=================

  * [Prerequisites](#prerequisites)
  * [Instructions to create a VM and to ssh to it](#instructions-to-create-a-vm-and-to-ssh-to-it)
  * [Customizing the Fedora Cloud image](#customizing-the-fedora-cloud-image)
  * [Build a Quarkus application using Tekton](#build-a-quarkus-application-using-tekton)
      * [Replay the pipeline](#replay-the-pipeline)
  * [End-to-end test](#end-to-end-test)
  * [Access podman remotely](#access-podman-remotely)
  * [GitHub Workflows](#github-workflows)
  * [Issues](#issues)

## Prerequisites

- [virtctl](https://docs.openshift.com/container-platform/4.13/virt/virt-using-the-cli-tools.html#installing-virtctl_virt-using-the-cli-tools) client (optional)
- [Tekton client](https://tekton.dev/docs/cli/)
- ocp cluster >= 4.13
- Tekton & Kubevirt operators installed

## Instructions to create a VM and to ssh to it

- Log on to your OCP cluster
- Deploy the `HyperConverged` CR to enable the nested virtualization features:
```bash
kubectl apply -f resources/hyperconverged.yml
```
- Create or select a project/namespace
```bash
oc new-project <NAMESPACE>
```
- Create a Kubernetes secret using your public key needed to ssh to the VM
```bash
kubectl create secret generic quarkus-dev-ssh-key -n <NAMESPACE> --from-file=key=~/.ssh/<PUBLIC_KEY_FILE>.pub                  
```
- Create the `DataVolume` on the cluster (which is a PVC) using the Fedora Quarkus Dev VM image pushed on: `quay.io/snowdrop/quarkus-dev-vm`
```bash
kubectl apply -n openshift-virtualization-os-images -f resources/quay-to-pvc-datavolume.yml
```
**NOTE**: This step should be performed only once. If you have already created the DataVolume, then you can skip this step and move to the next one.

- When done, create a VirtualMachine
```bash
kubectl delete -n <NAMESPACE> vm/quarkus-dev
kubectl apply -n <NAMESPACE> -f resources/quarkus-dev-virtualmachine.yml
```
- If a loadbalancer is available on the platform where the cluster is running, then deploy a Service of type `Loabalancer` to access it using a ssh client
```bash
kubectl apply -f resources/services/service.yml
...
# Wait till you got an external IP address
VM_IP=$(kubectl get svc/quarkus-dev-loadbalancer-ssh-service -ojson | jq -r '.status.loadBalancer.ingress[].ip')
ssh -p 22000 fedora@$VM_IP
```

**NOTE**: If you have installed the virtctl client, you can also ssh to the vm using the following command able to forward the traffic:
```bash
virtctl ssh --local-ssh fedora@<VM_NAME>
```

## Customizing the Fedora Cloud image

By default, podman, socat packages are not installed within the Fedora Cloud image. They can be installed using `CloudInit` but that means that
the process to create a KubeVirt VirtualMachine will take more time. To avoid this, we have created a GitHub Action flow able to customize the Fedora cloud 
image using the tool: `virt-customize`. See: `.github/workflows/build-push-podman-remote-vm.yml`.

**Note**: The flow is not triggered for each commit and by consequence if some changes are needed, you will have first to push your changes and next to launch the flow using either the GitHub Action UI or the client `gh workflow run build-push-podman-remote-vm.yml`

The image generated is available under the Quay registry: `quay.io/snowdrop/quarkus-dev-vm`
The image can be next deployed `kubectl apply -n openshift-virtualization-os-images -f resources/quay-to-pvc-datavolume.yml` within the ocp cluster using a DataVolume resource under the namespace hosting the different OSes `openshift-virtualization-os-images`

Now, you will be able to consume it for every VirtualMachine you will create if you include this `DataVolumeTemplate`: 
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: quarkus-dev
  labels:
    app: quarkus-dev
spec:
  dataVolumeTemplates:
    - apiVersion: cdi.kubevirt.io/v1beta1
      kind: DataVolume
      metadata:
        name: quarkus-dev
      spec:
        pvc:
          accessModes:
          - ReadWriteOnce
          resources:
            requests:
              storage: 11Gi
        source:
          pvc:
            namespace: openshift-virtualization-os-images
            name: podman-remote
```

## Build a Quarkus application using Tekton

First create the pvc used to git clone and build quarkus
```bash
cd pipelines 
kubectl apply -f setup/project-pvc.yaml
kubectl apply -f setup/m2-repo-pvc.yaml
kubectl apply -f setup/configmap-maven-settings.yaml
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

kubectl apply -f tasks/rm-workspace.yaml
kubectl apply -f tasks/git-clone.yaml
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

**NOTE**: If you experiment an issue when a container is created during the creation of a testcontainer, you can then modify the `create-remote-container` included within the pipeline `quarkus-maven-build` to and set the parameter `debug` to `true` within the PipelineRun `quarkus-maven-build-run`

### Replay the pipeline

To replay the Pipeline, it is needed to delete first the git cloned project and its pvc otherwise the step will report this error: `[git-clone : clone] fatal: destination path '.' already exists and is not an empty directory.`
```bash
kubectl delete -f pipelineruns/quarkus-maven-build-run.yaml
kubectl delete -f setup/project-pvc.yaml
kubectl apply -f setup/project-pvc.yaml
kubectl apply -f pipelineruns/quarkus-maven-build-run.yaml
tkn pr logs quarkus-maven-build-run -f
```

## End-to-end test

To play with Kubevirt & Tekton to execute an end-to-end test case where we:
- Create a Virtual Machine 
- Provision it to install podman, socat
- Expose the podman daemon using socat
- Deploy a Tekton pipeline on the cluster and launch it to git clone a Quarkus application and build it
- Consult the log of the pipeline to verify if the maven succeeds as it use a testcontainer (e.g postgresql) and access remotely podman

execute this command:
```bash
./e2e.sh -v <VM_NAME> -n <NAMESPACE> -p <PUBLIC_KEY_FILE_PATH>
```
where:
- <VM_NAME>: name of the virtual machine and also OS image to download (e.g. Fedora Cloud customized = quay.io/snowdrop/quarkus-dev-vm)
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

## GitHub Workflows

This project includes some GitHub Actions flows able to:
- Build and push the Fedora Cloud image customized with podman, socat on quay/snowdrop. See: `.github/workflows/build-push-podman-remote-vm.yml`
- Create a kind cluster + kubevirt and perform using Tekton the [End-to-end scenario](#end-to-end-test): See: `.github/workflows/kubevirt-podman-remote-quarkus-helloworld.yaml`

**WARNING**: Due to the following JIB build [issue](https://github.com/quarkusio/quarkus/issues/37469), we cannot build and deploy the resources yet using the GitHub workflow - kubevirt-podman-remote-quarkus-helloworld.yaml

**NOTE**: As the target platform used here is kubernetes and not ocp, then some adjustments are needed .This is the reason why different `kustomization.yaml` files have been created !

**NOTE**: The flow to build the customized image must be executed manually using the GitHub UI or client !

## Issues

The step to set up a network bridge is not needed to allow the pods to access the VM within the cluster as a Kuybernetes Service is required in this case
When we tried to use the `Network Attachment Definition`een faced to the following error: `0/6 nodes are available: 3 Insufficient devices.kubevirt.io/kvm, 3 Insufficient devices.kubevirt.io/tun, 3 Insufficient devices.kubevirt.io/vhost-net, 3 node(s) didn't match node selector, 6 Insufficient bridge-cni.network.kubevirt.io/br1`. 
To fix it, follow the instructions described within this ticket: https://bugzilla.redhat.com/show_bug.cgi?id=1727810

**TIP**: Don't create using ocp 4.13.x the bridge using the UI as documented [here](https://github.com/rhpds/roadshow_ocpvirt_instructions/blob/summit/workshop/content/06_network_management.adoc)e can also create a service using the virtctl client: `virtctl expose vmi quarkus-dev --name=quarkus-dev --port=2376 --target-port=2376`
