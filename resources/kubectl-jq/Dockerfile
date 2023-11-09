#  docker build . -t ghcr.io/ch007m/kubectl-jq
#  docker push ghcr.io/ch007m/kubectl-jq
FROM quay.io/swsmirror/bash

RUN apk --no-cache add curl jq
RUN curl -sLO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

ENTRYPOINT ["/usr/local/bin/kubectl"]