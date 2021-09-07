variable "region" {
  type        = string
  default     = "us-east-1"
  description = " Target AWS region for infra creation. Default is Virginia"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-1c", "us-east-1b"]
  description = "Availability zones for the default Ireland region."
}

variable "single_zone" {
  type        = list(string)
  default     = ["us-east-1c"]
  description = "Availability zones for Virgia region for infra creation."
}

variable "bastion_instance_types" {
  type        = list(string)
  description = "Bastion instance types used for spot instances."
  default     = ["t2.nano", "t3a.micro"]
}

variable "worker_instance_types" {
  type        = string
  description = "Worker instance types used for spot instances."
  default     = "m5.large,m5d.large,m5a.large,m5ad.large,m5n.large,m5dn.large"
}

variable "vpc_cidr" {
  type        = string
  description = "Amazon Virtual Private Cloud Classless Inter-Domain Routing range."
  default     = "10.0.0.0/16"
}

variable "private_subnets_cidrs" {
  type        = list(string)
  description = "Classless Inter-Domain Routing ranges for private subnets."
  default     = ["10.0.0.0/21", "10.0.8.0/21"]
}

variable "public_subnets_cidrs" {
  type        = list(string)
  description = "Classless Inter-Domain Routing ranges for public subnets."
  default     = ["10.0.17.0/24", "10.0.18.0/24"]
}

variable "eks_enabled_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "tags" {
  type        = map(string)
  description = "Default tags attached to all resources."
  default = {
    Environment = "local",
    createdBy   = "shankar",
    Service     = "app-sre",
    RegionAbbre = "us-east-1"
  }
}

variable "eks_version" {
  type        = string
  description = "Amazon EKS version"
  default     = "1.20"
}

variable "eks_version_latest_ami" {
  type        = string
  description = "This might not required since ssm module gets the latest ami"
  default     = "1.20"
}

variable "create_cluster" {
  type    = bool
  default = true
}

variable "ssh_key_name" {
  default = "eks-ami"
}

variable "hosted_zone_id" {
  description = "Hosted zone id used by bastion host."
  default     = ""
}

variable "spot_worker_instance_type" {
  default = "m5.large"
}

variable "vpc_single_nat_gateway" {
  type    = bool
  default = true
}

variable "vpc_one_nat_gateway_per_az" {
  type    = bool
  default = false
}

variable "ondemand_number_of_nodes" {
  type        = number
  description = "On-demand desired size nodes for Managed Node Group"
  default     = 0
}

variable "ondemand_min_number_of_nodes" {
  type        = number
  description = "On-demand minimum size nodes for Managed Node Group"
  default     = 1
}

variable "ondemand_percentage_above_base" {
  type        = number
  description = "% of On-demand instance for Managed Node Group"
  default     = 0
}

variable "desired_number_worker_nodes" {
  type    = number
  default = 1
}

variable "min_number_worker_nodes" {
  type    = number
  default = 1
}

variable "max_number_worker_nodes" {
  type    = number
  default = 2
}

variable "aws_role_arn" {
  type        = string
  description = "**IMPORTANT** -> Role for cluster creation. Read from .tfvar file or environment variable TF_VAR_AWS_ROLE_ARN"
}

variable "oidc_thumbprint_list" {
  type    = list(any)
  default = []
}

variable "enable_spot_workers" {
  type    = bool
  default = true
}

variable "enable_managed_workers" {
  type    = bool
  default = true
}

variable "spot_worker_enable_asg_metrics" {
  type        = string
  description = "Enable Auto Scaling Group Metrics on spot worker."
  default     = "yes"
}

variable "managed_node_group_instance_types" {
  type        = string
  description = "(Optional) String of instance types associated with the EKS Managed Node Group. Terraform will only perform drift detection if a configuration value is provided. Currently, the EKS API only accepts a single value."
  default     = "t3.medium"
}

variable "managed_node_group_release_version" {
  type        = string
  description = "AMI version of the EKS Node Group. Available versions in https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html"
  default     = "1.20.4-20210628"
}

variable "spot_worker_restrict_metadata_access" {
  type        = string
  description = "Restrict access to ec2 instance profile credentials"
  default     = "no"
}

## Contruct below 2 parameters as map & run for_each loop to create role+service account for multiple namespace

variable "custom_pod_namespace" {
  type        = string
  description = "Name space reserved for application pod. The pod-reader SA (iam role for pod) account is mapped to this namespace"
  default     = "app-ns"
}

variable "admin_namespace" {
  type        = string
  description = "Name space reserved for infra admin components. Should not be used for App pods"
  default     = "sre"
}

variable "mn_node_label" {
  type        = string
  description = "Node-lable to be attached to eks managed node-group via custom launch template.. Must be comma seperated"
  default     = "sentientblog.io/namespace=sre"
}

variable "spot_node_label" {
  type        = string
  description = "Node-lable to be attached to eks unmanaged/spot node-group via custom launch template.. Must be comma seperated"
  default     = "sentientblog.io/namespace=app-ns"
}

variable "pod_sa_name" {
  type        = string
  description = "sample Service account name for pods to be deployed"
  default     = "pod-reader-sa"
}


variable "create_eks_addons" {
  type        = bool
  description = "Enable EKS managed addons creation."
  default     = true
}

variable "eks_addon_version_kube_proxy" {
  type        = string
  description = "Kube proxy managed EKS addon version."
  default     = "v1.20.4-eksbuild.2"
}

variable "eks_addon_version_core_dns" {
  type        = string
  description = "Core DNS managed EKS addon version."
  default     = "v1.8.3-eksbuild.1"
}

## For enabling local provisioner which install other useful/extra cluster utilites like ebs csi driver. pls check local provisioner block. Make sure to modify the **helm values or other path manifest**

variable "create_eks_utilities" {
  type        = bool
  description = "Enable extra utilities as part of local provisioner"
  default     = false
}

## To be enabled for 1.21 Upgrade

# variable "eks_addon_version_kube_proxy" {
#   type        = string
#   description = "Kube proxy managed EKS addon version."
#   default     = "v1.21.2-eksbuild.2"
# }

# variable "eks_addon_version_core_dns" {
#   type        = string
#   description = "Core DNS managed EKS addon version."
#   default     = "v1.8.4-eksbuild.1"
# }

# variable "container_runtime" {
#   type        = string
#   description = "Container runtime used by EKS worker nodes. Allowed values: `dockerd` and `containerd`."
#   default     = "containerd"
# }
