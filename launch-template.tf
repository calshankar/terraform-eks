resource "aws_launch_template" "worker_template" {
  name     = "${local.name_prefix}-worker-nodes-LT"
  image_id = data.aws_ssm_parameter.eks_optimized_ami_id.value

  key_name = var.ssh_key_name

  placement {
    availability_zone = "us-east-1c"
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 25
      volume_type = "gp3"
    }
  }
  tags = {
    source = "Terraform"
    Name   = "${local.name_prefix}-worker-nodes-LT"
  }
  vpc_security_group_ids = ["${aws_security_group.nonmanaged_workers_sg[0].id}", module.bastion.security_group_id]

  user_data = base64encode(templatefile("./scripts/userdata.sh.tpl", { CLUSTER_NAME = aws_eks_cluster.cluster[0].id, B64_CLUSTER_CA = aws_eks_cluster.cluster[0].certificate_authority[0].data, API_SERVER_URL = aws_eks_cluster.cluster[0].endpoint, RESTRICT_METADATA = var.spot_worker_restrict_metadata_access }))

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
    aws_cloudwatch_log_group.cluster,
    aws_eks_cluster.cluster,
    aws_iam_role.managed_workers
  ]
}

#####
# Outputs
#####

output "eks_launch_template_id" {
  value = data.aws_launch_template.worker_template.id
}

output "eks_launch_template_name" {
  value = aws_launch_template.worker_template.name
}

output "eks_launch_template_ver" {
  value = data.aws_launch_template.worker_template.latest_version
}