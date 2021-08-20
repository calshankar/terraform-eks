SHELL := /usr/bin/env bash
# All is the first target in the file so it will get picked up when you just run 'make' on its own

all-test: clean tf-plan-test

.PHONY: clean
clean:
	rm -rf .terraform

.PHONY: tf-init
tf-init:
	terraform init && terraform fmt && terraform validate

.PHONY: tf-apply
tf-apply:
	terraform apply -auto-approve 2>&1 | tee ./eks_tf_plan