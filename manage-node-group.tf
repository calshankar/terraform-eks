module "eks-node-group" {
  source = "./modules/eks-node-group-spot1"

  count           = var.enable_managed_workers ? 1 : 0
  create_iam_role = false

  cluster_name  = var.create_cluster ? aws_eks_cluster.cluster[0].name : null
  node_role_arn = var.enable_managed_workers ? aws_iam_role.managed_workers[0].arn : 0
  subnet_ids    = [module.vpc.private_subnets[0]]

  desired_size = 1
  min_size     = var.ondemand_min_number_of_nodes
  max_size     = 3

  instance_types = ["t3.large", "t3a.large"]

  capacity_type = "SPOT"

  launch_template = {
    id      = data.aws_launch_template.worker_template.id
    version = data.aws_launch_template.worker_template.latest_version
  }

  labels = {
    lifecycle = "Ec2Spot"
  }

  tags       = var.tags
  depends_on = [aws_launch_template.worker_template]
}

module "eks-node-group-spotB" {
  source = "./modules/eks-node-group-spot2"

  count           = var.enable_managed_workers ? 1 : 0
  create_iam_role = false

  cluster_name  = var.create_cluster ? aws_eks_cluster.cluster[0].name : null
  node_role_arn = var.enable_managed_workers ? aws_iam_role.managed_workers[0].arn : 0
  subnet_ids    = [module.vpc.private_subnets[0]]

  desired_size = 1
  min_size     = var.ondemand_min_number_of_nodes
  max_size     = 3

  instance_types = ["t3.large", "t3a.large"]

  capacity_type = "SPOT"

  launch_template = {
    id      = data.aws_launch_template.worker_template.id
    version = data.aws_launch_template.worker_template.latest_version
  }

  labels = {
    lifecycle = "Ec2Spot"
  }

  tags       = var.tags
  depends_on = [aws_launch_template.worker_template]
}

resource "random_id" "iam_policy_suffix" {
  byte_length = 4
}

resource "aws_iam_role" "managed_workers" {
  count = var.enable_managed_workers && var.create_cluster ? 1 : 0

  name = "${local.name_prefix}-managed-worker-node"

  assume_role_policy = data.aws_iam_policy_document.managed_workers_role_assume_role_policy.json

  tags = var.tags
}

resource "aws_iam_policy" "managed-worker-node-custom-policy" {
  name   = "${local.name_prefix}-custom-policy-${random_id.iam_policy_suffix.hex}"
  policy = templatefile("policies/worker_node_custom_policy.json", {})
}

resource "aws_iam_role_policy_attachment" "wroker-node-custom-policy" {
  policy_arn = aws_iam_policy.managed-worker-node-custom-policy.arn
  role       = aws_iam_role.managed_workers[0].name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSWorkerNodePolicy" {
  count      = var.enable_managed_workers && var.create_cluster ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.managed_workers[0].name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKS_CNI_Policy" {
  count      = var.enable_managed_workers && var.create_cluster ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.managed_workers[0].name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEC2ContainerRegistryReadOnly" {
  count      = var.enable_managed_workers && var.create_cluster ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.managed_workers[0].name
}

#####
# Outputs
#####

output "managed_worker_node_role_arn" {
  value = aws_iam_role.managed_workers[0].arn
}

output "managed_worker_node_custom_policy_arn" {
  value = aws_iam_policy.managed-worker-node-custom-policy.arn
}