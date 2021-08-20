#####
# Additional IAM roles and policies for service running inside EKS
# All IAM roles in this configuration make use of OIDC provider
#####

# Used by alb_ingress_controller service account

resource "aws_iam_role" "load_balancer_controller" {
  count = var.create_cluster ? 1 : 0

  name = "${local.name_prefix}-load-balancer-controller"

  assume_role_policy = templatefile("policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.cluster[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", ""), NAMESPACE = "kube-system", SA_NAME = "aws-load-balancer-controller" })

  tags = merge(
    var.tags,
    {
      "ServiceAccountName"      = "aws-load-balancer-controller"
      "ServiceAccountNameSpace" = "kube-system"
    }
  )

  depends_on = [aws_iam_openid_connect_provider.cluster]
}

resource "aws_iam_role_policy" "load_balancer_controller" {
  count = var.create_cluster ? 1 : 0

  name = "CustomPolicy"
  role = aws_iam_role.load_balancer_controller[0].id

  policy = data.aws_iam_policy_document.load_balancer_controller.json
}

# Used by cluster_autoscaler service account

resource "aws_iam_role" "cluster_autoscaler" {
  count = var.create_cluster ? 1 : 0

  name = "${local.name_prefix}-cluster-autoscaler"

  assume_role_policy = templatefile("policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.cluster[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", ""), NAMESPACE = "kube-system", SA_NAME = "cluster-autoscaler" })

  tags = merge(
    var.tags,
    {
      "ServiceAccountName"      = "cluster-autoscaler"
      "ServiceAccountNameSpace" = "kube-system"
    }
  )

  depends_on = [aws_iam_openid_connect_provider.cluster]
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count = var.create_cluster ? 1 : 0

  name = "CustomPolicy"
  role = aws_iam_role.cluster_autoscaler[0].id

  policy = data.aws_iam_policy_document.cluster_autoscaler.json
}

# Used by external_secrets service account

resource "aws_iam_role" "external_secrets" {
  count = var.create_cluster ? 1 : 0

  name = "${local.name_prefix}-external-secrets"

  assume_role_policy = templatefile("policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.cluster[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", ""), NAMESPACE = "default", SA_NAME = "external-secrets" })

  tags = merge(
    var.tags,
    {
      "ServiceAccountName"      = "external-secrets"
      "ServiceAccountNameSpace" = "default"
    }
  )

  depends_on = [aws_iam_openid_connect_provider.cluster]
}

resource "aws_iam_role_policy" "external_secrets" {
  count = var.create_cluster ? 1 : 0

  name = "CustomPolicy"
  role = aws_iam_role.external_secrets[0].id

  policy = data.aws_iam_policy_document.external_secrets.json
}

# Used by external-dns service account

resource "aws_iam_role" "external_dns" {
  count = var.create_cluster ? 1 : 0

  name = "${local.name_prefix}-external-dns"

  assume_role_policy = templatefile("policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.cluster[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", ""), NAMESPACE = "kube-system", SA_NAME = "external-dns" })

  tags = merge(
    var.tags,
    {
      "ServiceAccountName"      = "external-dns"
      "ServiceAccountNameSpace" = "kube-system"
    }
  )

  depends_on = [aws_iam_openid_connect_provider.cluster]
}

resource "aws_iam_role_policy" "external_dns" {
  count = var.create_cluster ? 1 : 0

  name = "CustomPolicy"
  role = aws_iam_role.external_dns[0].id

  policy = data.aws_iam_policy_document.external_dns.json
}

# Used by ebs-csi driver service account

resource "aws_iam_role" "ebs_csi_driver" {
  count = var.create_cluster ? 1 : 0

  name = "${local.name_prefix}-ebs-csi-driver"

  assume_role_policy = templatefile("policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.cluster[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", ""), NAMESPACE = "kube-system", SA_NAME = "ebs-csi-controller-sa" })

  tags = merge(
    var.tags,
    {
      "ServiceAccountName"      = "ebs-csi-controller-sa"
      "ServiceAccountNameSpace" = "kube-system"
    }
  )

  depends_on = [aws_iam_openid_connect_provider.cluster]
}

resource "aws_iam_policy" "ebs_csi_driver_policy" {
  name   = "${local.name_prefix}-ebs_csi_driver-${random_id.iam_policy_suffix.hex}"
  policy = templatefile("policies/ebs_csi_iam_policy.json", {})
}

resource "aws_iam_role_policy_attachment" "ebs-attach" {
  role       = aws_iam_role.ebs_csi_driver[0].id
  policy_arn = aws_iam_policy.ebs_csi_driver_policy.arn
}

# Used by cloudwatch-agent service account

resource "aws_iam_role" "cloudwatch_agent" {
  count = var.create_cluster ? 1 : 0

  name = "${local.name_prefix}-cloudwatch-agent"

  assume_role_policy = templatefile("policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.cluster[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", ""), NAMESPACE = "amazon-cloudwatch", SA_NAME = "cloudwatch-agent" })

  tags = merge(
    var.tags,
    {
      "ServiceAccountName"      = "cloudwatch-agent"
      "ServiceAccountNameSpace" = "amazon-cloudwatch"
    }
  )

  depends_on = [aws_iam_openid_connect_provider.cluster]
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_CloudWatchAgentServerPolicy" {
  count = var.create_cluster ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_agent[0].name
}

## General Pod reader role.. For permission check pod_reader.json. Pls chk the docs @ https://docs.aws.amazon.com/eks/latest/userguide/create-service-account-iam-policy-and-role.html

resource "aws_iam_role" "pod_reader" {
  count = var.create_cluster ? 1 : 0

  name = "${local.name_prefix}-pod-reader"

  assume_role_policy = templatefile("policies/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.cluster[0].arn, OIDC_URL = replace(aws_iam_openid_connect_provider.cluster[0].url, "https://", ""), NAMESPACE = var.custom_pod_namespace, SA_NAME = var.pod_sa_name })

  tags = merge(
    var.tags,
    {
      "ServiceAccountName"      = var.pod_sa_name
      "ServiceAccountNameSpace" = var.custom_pod_namespace
    }
  )

  depends_on = [aws_iam_openid_connect_provider.cluster]
}

resource "aws_iam_policy" "pod_reader_policy" {
  name   = "${local.name_prefix}-pod_reader-${random_id.iam_policy_suffix.hex}"
  policy = templatefile("policies/pod_reader.json", {})
}

resource "aws_iam_role_policy_attachment" "pod-attach" {
  role       = aws_iam_role.pod_reader[0].id
  policy_arn = aws_iam_policy.pod_reader_policy.arn
}

#####
# Outputs
#####

output "iam_role_arn_load_balancer_controller" {
  value = join("", aws_iam_role.load_balancer_controller.*.arn)
}

output "iam_role_arn_cluster_autoscaler" {
  value = join("", aws_iam_role.cluster_autoscaler.*.arn)
}

output "iam_role_arn_external_secrets" {
  value = join("", aws_iam_role.external_secrets.*.arn)
}

output "iam_role_arn_external_dns" {
  value = join("", aws_iam_role.external_dns.*.arn)
}

output "iam_role_arn_ebs_csi_driver" {
  value = join("", aws_iam_role.ebs_csi_driver.*.arn)
}

output "iam_role_arn_cloudwatch_agent" {
  value = join("", aws_iam_role.cloudwatch_agent.*.arn)
}

output "iam_role_arn_pod_reader" {
  value = join("", aws_iam_role.pod_reader.*.arn)
}