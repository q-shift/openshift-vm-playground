## Tekton Task to customize KubeVirt imagegit 

Useful link: https://cloud.redhat.com/blog/building-vm-images-using-tekton-and-secrets

```bash
#kubectl delete -f vms/virt-custom/dv-fedora39-cloud-base.yml
#kubectl apply -f vms/virt-custom/dv-fedora39-cloud-base.yml

kubectl delete -f vms/virt-custom/dv-containerdisks-fedora38.yml
kubectl apply -f  vms/virt-custom/dv-containerdisks-fedora38.yml

kubectl delete -f vms/virt-custom/secret.yml
kubectl apply -f vms/virt-custom/secret.yml

kubectl delete -f vms/virt-custom/virt-custom-task.yml
kubectl apply -f vms/virt-custom/virt-custom-task.yml
#kubectl apply -f https://github.com/kubevirt/kubevirt-tekton-tasks/releases/download/v0.16.0/kubevirt-tekton-tasks-okd.yaml

kubectl delete -f vms/virt-custom/virt-custom-taskrun.yml
kubectl apply -f vms/virt-custom/virt-custom-taskrun.yml
```

