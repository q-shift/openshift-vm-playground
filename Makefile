REG ?= quay.io
ORG ?= ch007m
VM_IMAGE_BUILDER_IMAGE_NAME := virt-builder
VM_IMAGE_BUILDER_IMAGE_TAG ?= latest

build-vm-image-builder:
	docker build $(CURDIR)/vms/image-builder -f $(CURDIR)/vms/image-builder/Dockerfile -t $(REG)/$(ORG)/$(VM_IMAGE_BUILDER_IMAGE_NAME):$(VM_IMAGE_BUILDER_IMAGE_TAG)
.PHONY: build-vm-image-builder