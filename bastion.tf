module "bastion" {
  source      = "./modules/bastion"
  name_prefix = local.name_prefix

  vpc_id              = module.vpc.vpc_id
  public_subnets      = flatten(module.vpc.public_subnets)
  ingress_cidr_blocks = ["${chomp(data.http.myip.body)}/32"]

  hosted_zone_id = var.hosted_zone_id
  ssh_key_name   = var.ssh_key_name

  tags = var.tags
}

output "bastion_security_group_id" {
  value = module.bastion.security_group_id
}
