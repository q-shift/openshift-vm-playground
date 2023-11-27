REG ?= quay.io
ORG ?= ch007m
VM_IMAGE_BUILDER_IMAGE_NAME := virt-builder
VM_IMAGE_BUILDER_IMAGE_TAG ?= latest
VIRT_BUILDER_CACHE_DIR := $(CURDIR)/_virt_builder/cache
VIRT_BUILDER_OUTPUT_DIR := $(CURDIR)/_virt_builder/output
VM_CONTAINER_DISK_IMAGE_NAME := quarkus-dev-vm
VM_CONTAINER_DISK_IMAGE_TAG ?= latest
CURRENT_DIR := $(shell pwd)

build-vm-image-builder:
	docker build $(CURDIR)/vms/image-builder -f $(CURDIR)/vms/image-builder/Dockerfile -t $(REG)/$(ORG)/$(VM_IMAGE_BUILDER_IMAGE_NAME):$(VM_IMAGE_BUILDER_IMAGE_TAG)
.PHONY: build-vm-image-builder

build-vm-image: build-vm-image-builder
	mkdir -vp $(VIRT_BUILDER_CACHE_DIR)
	mkdir -vp $(VIRT_BUILDER_OUTPUT_DIR)

	docker container run --rm \
      --volume=$(VIRT_BUILDER_CACHE_DIR):/root/.cache/virt-builder:Z \
      --volume=$(VIRT_BUILDER_OUTPUT_DIR):/output:Z \
      --volume=$(CURDIR)/vms/quarkus-dev-vm/scripts:/root/scripts:Z \
      $(REG)/$(ORG)/$(VM_IMAGE_BUILDER_IMAGE_NAME):$(VM_IMAGE_BUILDER_IMAGE_TAG) \
      /root/scripts/build-vm-image
.PHONY: build-vm-image

build-vm-container-disk: build-vm-image
	docker build $(CURDIR) -f $(CURDIR)/vms/quarkus-dev-vm/Dockerfile -t $(REG)/$(ORG)/$(VM_CONTAINER_DISK_IMAGE_NAME):$(VM_CONTAINER_DISK_IMAGE_TAG)
.PHONY: build-vm-container-disk

push-vm-container-disk:
	docker push $(REG)/$(ORG)/$(VM_CONTAINER_DISK_IMAGE_NAME):$(VM_CONTAINER_DISK_IMAGE_TAG)
.PHONY: push-vm-container-disk

