#!/usr/bin/env bash

#
# Command syntax
#  ./e2e.sh test1 <VM_NAME> <NAMESPACE> <PUBLIC_KEY_FILE_PATH>
#  Example: ./e2e.sh test1 fedora38 ~/.ssh/id_rsa.pub

# Check if at least two arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <namespace> <vm_name> <public_key_file_path>"
    exit 1
fi

if command -v virtctl &> /dev/null; then
   :  # Command exists, do nothing (null command)
else
  echo "Command 'virtctl' does not exist."
  exit 1
fi

NAMESPACE=$1
VM_NAME=$2
PUBLIC_KEY_FILE_PATH=$3

# Continue with the rest of your script using $namespace and $vm_name
echo "VM Name: $VM_NAME"

# Check if the namespace exists
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Namespace '$NAMESPACE' already exists."
else
    # Create the namespace
    kubectl create namespace "$NAMESPACE"
    echo "Namespace '$NAMESPACE' created."
fi

# Set the namespace as the current context
kubectl config set-context --current --namespace="$NAMESPACE"

# Print the current context to verify
echo "Current context:"
kubectl config current-context

# Create the secret hosting the public key
kubectl create secret generic fedora-ssh-key --from-file=key=$PUBLIC_KEY_FILE_PATH

# Create the PVC used by Tekton and configMap
kubectl apply -f pipelines/setup/persistentvolumeclaim-project-pvc.yaml
kubectl apply -f pipelines/setup/configmap-maven-settings.yaml

# Deploying a VM
kubectl apply -f resources/vm-$VM_NAME.yml

# Wait till socat is up and running
# TODO: We should find a better way to track if socat is up and running
while true; do virtctl -n $NAMESPACE ssh --known-hosts $HOME/.ssh/known_hosts --local-ssh fedora@$VM_NAME -c "sudo netstat -tulpn | grep \":$port.*socat\"" && break; sleep 30; done

# Run the Tekton pipeline
kubectl apply -f pipelines/tasks/git-clone.yaml
kubectl apply -f pipelines/tasks/rm-workspace.yaml
kubectl apply -f pipelines/tasks/ls-workspace.yaml
kubectl apply -f pipelines/tasks/maven.yaml
kubectl apply -f pipelines/tasks/virtualmachine.yaml
kubectl apply -f pipelines/pipelines/quarkus-maven-build.yaml
kubectl apply -f pipelines/pipelineruns/quarkus-maven-build-run.yaml

tkn pr logs quarkus-maven-build-run -f

