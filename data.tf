data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Fetch latest ami_id for specified ${var.eks_version}
data "aws_ssm_parameter" "eks_optimized_ami_id" {
  name            = "/aws/service/eks/optimized-ami/${var.eks_version_latest_ami}/amazon-linux-2/recommended/image_id"
  with_decryption = true
}

data "tls_certificate" "cluster" {
  count = var.create_cluster ? 1 : 0

  url = aws_eks_cluster.cluster[0].identity.0.oidc.0.issuer
}

data "aws_iam_policy_document" "managed_workers_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "worker_node_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_launch_template" "worker_template" {
  name = aws_launch_template.worker_template.name

  depends_on = [aws_launch_template.worker_template]
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
  request_headers = {
    Accept = "application/json"
  }
}