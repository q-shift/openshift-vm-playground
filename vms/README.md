## Tekton Task to customize KubeVirt imagegit 

Useful link: https://cloud.redhat.com/blog/building-vm-images-using-tekton-and-secrets

```bash
#kubectl delete -f vms/virt-custom/dv-fedora39-cloud-base.yml
#kubectl apply -f vms/virt-custom/dv-fedora39-cloud-base.yml

kubectl delete -f vms/virt-custom/dv-containerdisks-fedora.yml
kubectl apply -f  vms/virt-custom/dv-containerdisks-fedora.yml

kubectl delete -f vms/virt-custom/secret.yml
kubectl apply -f vms/virt-custom/secret.yml

kubectl delete -f vms/virt-custom/virt-custom-task.yml
kubectl apply -f vms/virt-custom/virt-custom-task.yml

kubectl delete -f vms/virt-custom/virt-custom-taskrun.yml
kubectl apply -f vms/virt-custom/virt-custom-taskrun.yml
```

