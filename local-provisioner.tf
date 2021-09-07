resource "null_resource" "setup-kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${aws_eks_cluster.cluster[0].name} --role-arn ${var.aws_role_arn}"
  }
  depends_on = [
    aws_cloudformation_stack.spot_worker,
    aws_eks_addon.core_dns,
    aws_lambda_function.node_drainer
  ]
}

resource "null_resource" "cillium-setup" {
  provisioner "local-exec" {
    command = <<EOT
    kubectl -n kube-system delete daemonset aws-node
    helm repo add cilium https://helm.cilium.io/
    helm install cilium cilium/cilium --version 1.9.9 \
    --namespace kube-system \
    --set eni=true \
    --set ipam.mode=eni \
    --set egressMasqueradeInterfaces=eth0 \
    --set tunnel=disabled \
    --set nodeinit.enabled=true
    EOT
  }
  depends_on = [null_resource.setup-kubeconfig]
}

resource "null_resource" "auth-setup" {
  provisioner "local-exec" {
    command = <<EOT
    ROLE="    - rolearn: ${var.aws_role_arn}\n      username: master_designated_role\n      groups:\n        - system:masters"

    kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > /tmp/aws-auth-patch.yml

    kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"

    NODEROLE="    - rolearn: ${aws_iam_role.worker_node.arn}\n      username: system:node:{{EC2PrivateDNSName}}\n      groups:\n        - system:bootstrappers\n        - system:nodes"

    kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$NODEROLE\";next}1" > /tmp/aws-auth-patch.yml

    kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"
    EOT
  }
  depends_on = [
    null_resource.setup-kubeconfig,
    aws_cloudformation_stack.spot_worker,
    aws_eks_addon.core_dns
  ]
}

## sets up cluster role for full & read access
resource "null_resource" "console-access" {
  provisioner "local-exec" {
    command = <<EOT
    kubectl apply -f https://s3.us-west-2.amazonaws.com/amazon-eks/docs/eks-console-full-access.yaml

    kubectl apply -f https://s3.us-west-2.amazonaws.com/amazon-eks/docs/eks-console-restricted-access.yaml
    EOT
  }
  depends_on = [
    null_resource.setup-kubeconfig,
    null_resource.cillium-setup,
    aws_cloudformation_stack.spot_worker,
    aws_eks_addon.core_dns
  ]
}

## sets up ebs csi driver
resource "null_resource" "ebs-csi-driver" {

  count = var.create_eks_utilities ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
    ## GP3+standard storage class
    kubectl create -f ./eks_manifest/gp3-storage-class.yaml
    kubectl create -f ./eks_manifest/standard.yaml

    helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
    helm repo update

    helm upgrade -install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
    --namespace kube-system \
    --set image.repository=602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/aws-ebs-csi-driver \
    --set enableVolumeResizing=true \
    --set enableVolumeSnapshot=true \
    --set serviceAccount.controller.create=true \
    --set serviceAccount.controller.name=ebs-csi-controller-sa

    kubectl annotate serviceaccount ebs-csi-controller-sa \
    -n kube-system \
    eks.amazonaws.com/role-arn=iam_role_arn_ebs_csi_driver.value --overwrite

    # Deleting pod to ensure annotation to come into effect
    kubectl delete pods \
    -n kube-system \
    -l=app=ebs-csi-controller
    EOT
  }
  depends_on = [
    null_resource.setup-kubeconfig,
    null_resource.cillium-setup,
    aws_eks_addon.core_dns,
    null_resource.console-access
  ]
}

## Set up service account for pod-reader
resource "null_resource" "pod-reader-sa" {
  provisioner "local-exec" {
    command = <<EOT

    kubectl create ns ${var.custom_pod_namespace}

    kubectl create ns ${var.admin_namespace}

    kubectl create sa ${var.pod_sa_name} -n ${var.custom_pod_namespace}

    kubectl annotate serviceaccount ${var.pod_sa_name} \
    -n ${var.custom_pod_namespace} \
    eks.amazonaws.com/role-arn=iam_role_arn_pod_reader.value --overwrite

    EOT
  }
  depends_on = [
    null_resource.setup-kubeconfig,
    aws_eks_addon.core_dns,
    null_resource.cillium-setup
  ]
}

## cluster component

resource "null_resource" "cluster-component" {
  provisioner "local-exec" {
    command = <<EOT

    ## Setting up Priority class
    kubectl create -f ./eks_manifest/priority-classes.yaml

    ## Add cluster autoscaler
    helm repo add autoscaler https://kubernetes.github.io/autoscaler
    ## Bitnami charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    ##
    helm repo update

    helm install my-release autoscaler/cluster-autoscaler \
    --set 'autoDiscovery.clusterName'=eks_cluster_name.value

    ## Add metric server..
    kubectl create -f ./eks_manifest/metrics-server/components.yaml

    sleep 5

    ## Add Predictive HPA -> https://predictive-horizontal-pod-autoscaler.readthedocs.io/en/latest/user-guide/getting-started/

    # VERSION=v1.0.3
    # HELM_CHART=custom-pod-autoscaler-operator
    helm install custom-pod-autoscaler-operator https://github.com/jthomperoo/custom-pod-autoscaler-operator/releases/download/v1.0.3/custom-pod-autoscaler-operator-v1.0.3.tgz

    EOT
  }
  depends_on = [
    null_resource.setup-kubeconfig,
    null_resource.pod-reader-sa,
    aws_eks_addon.core_dns,
    null_resource.cillium-setup
  ]
}

## other useful/extra cluster utilites

resource "null_resource" "useful-utility" {

  count = var.create_eks_utilities ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT

    helm install my-release autoscaler/cluster-autoscaler \
    --set 'autoDiscovery.clusterName'=eks_cluster_name.value

    ## Reloading pods in deployments, STS, RS on Configmap/secret change
    helm repo add stakater https://stakater.github.io/stakater-charts
    ## Eks charts repo
    helm repo add eks https://aws.github.io/eks-charts
    ## Add EBS csi-driver
    helm repo add secrets-store-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts
    helm repo update

    # Applying it for single namespace. Check chart values for config
    helm install stakater/reloader --set reloader.watchGlobally=false --namespace ${var.admin_namespace} --generate-name

    ## Installing external. Requires service account with R53 iam permission
    ## Add this annotation to ingress --> "external-dns.alpha.kubernetes.io/hostname: www.mydomain.com"

    helm install external-dns -f ./eks_manifest/private/external_dns/values.yaml bitnami/external-dns --namespace ${var.admin_namespace}

    ##kubectl annotate serviceaccount external-dns --namespace ${var.admin_namespace} eks.amazonaws.com/role-arn=iam_role_arn_external_dns.value --overwrite

    ## Install CSI secrets store
    helm install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver

    # AWS Provider for Secrets Manger -> https://github.com/aws/secrets-store-csi-driver-provider-aws

    kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

    ## Add node termination handler for unmanaged node group. Use --set webhookURL=<slackurl> for notification
    helm upgrade --install aws-node-termination-handler \
    --namespace kube-system \
    --set enableSpotInterruptionDraining="true" \
    --set enableRebalanceMonitoring="true" \
    --set enableScheduledEventDraining="false" \
    --set nodeSelector.lifecycle=Ec2Spot \
    eks/aws-node-termination-handler

    ## Install AWS load balancer controller
    helm install aws-loadbalancer-controller --namespace ${var.admin_namespace} --values  ./eks_manifest/private/awslb-controller-values/lb-controller-values.yaml eks/aws-load-balancer-controller

    EOT
  }
  depends_on = [
    null_resource.setup-kubeconfig,
    null_resource.cillium-setup,
    aws_eks_addon.core_dns,
    null_resource.cluster-component
  ]
}