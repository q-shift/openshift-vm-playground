#!/usr/bin/env bash

#
# Command syntax
#  ./e2e.sh test1 -v <VM_NAME> -n <NAMESPACE> -p <PUBLIC_KEY_FILE_PATH>
#  Examples:
#
#   ./e2e.sh 
#   ./e2e.sh -v fedora38
#   ./e2e.sh -v fedora38 -p ~/.ssh/somekey_rsa.pub
#   ./e2e.sh -n test1 -v fedora38 -p ~/.ssh/id_rsa.pub

if command -v virtctl &> /dev/null; then
   :  # Command exists, do nothing (null command)
else
  echo "Command 'virtctl' does not exist."
  exit 1
fi

NAMESPACE=""
VM_NAME="fedora38"
PUBLIC_KEY_FILE_PATH="${HOME}/.ssh/id_rsa.pub"

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--namespace)
      NAMESPACE="$2"
      shift
      ;;
    -v|--vm-name)
      VM_NAME="$2"
      shift
      ;;
    -p|--public-key-file)
      PUBLIC_KEY_FILE_PATH="$2"
      shift
      ;;
    -*)
      echo "Error: Invalid option: $1"
      usage
      ;;
    *)
      break  # Break the loop when the first non-option argument is encountered
      ;;
  esac
  shift
done

# Function to format elapsed time
format_elapsed_time() {
    local elapsed_time=$1
    local minutes=$((elapsed_time / 60))
    local seconds=$((elapsed_time % 60))

    # Format the elapsed time
    printf "%02dm:%02ds\n" "$minutes" "$seconds"
}

if [ -n "$NAMESPACE" ]; then
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
else
  NAMESPACE=$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')
fi

# Continue with the rest of your script using $NAMESPACE and $VM_NAME
echo "VM name: $VM_NAME"
echo "Namespace: $NAMESPACE"
echo "Public key file: $PUBLIC_KEY_FILE_PATH"

# Create the secret hosting the public key
kubectl create secret generic fedora-ssh-key --from-file=key=$PUBLIC_KEY_FILE_PATH

# Create the PVCs needed by Tekton (project, m2) and ConfigMap containing the maven settings
kubectl apply -f pipelines/setup/project-pvc.yaml
kubectl apply -f pipelines/setup/m2-repo-pvc.yaml
kubectl apply -f pipelines/setup/configmap-maven-settings.yaml

# Measuring start time before to create a VM
start_time=$(date +%s)

# Deploying a VM
kubectl apply -f resources/vm-$VM_NAME.yml

# Wait till socat is up and running
#VM_IP=$(kubectl get vmi/${VM_NAME} -ojson | jq -r '.status.interfaces[] | .ipAddress')
#while true; do virtctl -n $NAMESPACE ssh --known-hosts $HOME/.ssh/known_hosts --local-ssh fedora@$VM_NAME -c "sudo netstat -tulpn | grep \":$port.*socat\"" && break; sleep 30; done

desired_state="Running"
timeout_seconds=300  # Set your desired timeout value
start_time=$(date +%s)

# Wait for the VirtualMachineInstance to be ready and in the desired state
while true; do
    # Get the VMI status in JSON format
    vmi_status=$(kubectl get vmi -n "$NAMESPACE" "$VM_NAME" -o json)

    # Check if VMI exists
    if [ -n "$vmi_status" ]; then
        # Check if the VMI is in the desired state
        vmi_phase=$(echo "$vmi_status" | jq -r '.status.phase')
        if [ "$vmi_phase" == "$desired_state" ]; then
            echo "VMI $VM_NAME is now in the '$desired_state' state."
            break
        else
            echo "VMI $VM_NAME is in the '$vmi_phase' state. Waiting..."
        fi
    else
        echo "VMI $VM_NAME does not exist. Waiting..."
    fi

    # Check if the timeout has been reached
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -ge "$timeout_seconds" ]; then
        echo "Timeout reached. Exiting."
        break
    fi

    sleep 10  # Adjust the sleep interval as needed
done

# Get the VM_IP
VM_IP=$(kubectl get vmi/${VM_NAME} -ojson | jq -r '.status.interfaces[] | .ipAddress')
echo "IP of the VM - $VM_NAME: $VM_IP"

# Run the pod
kubectl run -n "$NAMESPACE" podname-client --image=quay.io/podman/stable -- "sleep" "1000000" &

# Wait for the pod to be in the Running state
while true; do
    pod_status=$(kubectl get pod -n "$NAMESPACE" podname-client -ojsonpath='{.status.phase}')
    if [ "$pod_status" == "Running" ]; then
        break
    fi
    sleep 1
done
echo "Pod podname-client is in the Running state."

echo "Wait for the command within the pod to succeed"
echo ">>>> Command to be executed to check healthiness of podman & socat"
echo ">>>> kubectl exec -n "$NAMESPACE" podname-client -- podman \"-r\" \"--url=tcp://$VM_IP:2376\" \"version\""
while true; do
    kubectl exec -n "$NAMESPACE" podname-client -- podman "-r" "--url=tcp://$VM_IP:2376" "version" &> /dev/null
    if [ $? -eq 0 ]; then
        echo "Command within the pod succeeded."
        break
    else
        echo "Remote podman is not yet ready to reply.."
    fi
    sleep 20
done
kubectl delete pod -n "$NAMESPACE" podname-client

# Record end time
end_time=$(date +%s)

# Calculate elapsed time
elapsed_time=$((end_time - start_time))
formatted_elapsed_time=$(format_elapsed_time "$elapsed_time")
echo "Creating a VM and provisioning it took: $formatted_elapsed_time"

# Run the Tekton pipeline
kubectl apply -f pipelines/tasks/git-clone.yaml
kubectl apply -f pipelines/tasks/rm-workspace.yaml
kubectl apply -f pipelines/tasks/ls-workspace.yaml
kubectl apply -f pipelines/tasks/maven.yaml
kubectl apply -f pipelines/tasks/virtualmachine.yaml
kubectl apply -f pipelines/pipelines/quarkus-maven-build.yaml
kubectl apply -f pipelines/pipelineruns/quarkus-maven-build-run.yaml

tkn pr logs quarkus-maven-build-run -f

