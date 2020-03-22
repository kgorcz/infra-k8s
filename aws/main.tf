provider "aws" {
    region = "us-east-2"
    version = "~> 1.0"
}

provider "template" {
    version = "~> 1.0"
}

resource "aws_key_pair" "client" {
    key_name = "ter-key"
    public_key = "${file("~/.ssh/id_rsa_aws.pub")}"
}

module "vpc" {
  source = "./modules/vpc"
  availability_zone = "us-east-2b"
}

module "bastion" {
  source = "./modules/bastion"
  vpc_id = "${module.vpc.vpc_id}"
  public_subnet_id = "${module.vpc.public_subnet_id}"
  key_name = "${aws_key_pair.client.key_name}"
  local_ip = "${var.local_ip}"
}

module "kubernetes_cluster_a" {
  source = "./modules/kubernetes_cluster"
  cluster_name = "${var.cluster_names[0]}"
  bastion_private_ip = "${module.bastion.private_ip}"
  bastion_public_ip = "${module.bastion.public_ip}"
  bastion_security_group_id = "${module.bastion.security_group_id}"
  key_name = "${aws_key_pair.client.key_name}"
  public_subnet_id = "${module.vpc.public_subnet_id}"
  private_subnet_id = "${module.vpc.private_subnet_id}"
  worker_count = "${var.worker_count}"
  vpc_id = "${module.vpc.vpc_id}"
  root_domain = "${var.root_domain}"
  domain_name = "${join(".", list(var.cluster_names[0], var.root_domain))}"
  letsencrypt_email = "${var.letsencrypt_email}"
}

# module "kubernetes_cluster_b" {
#   source = "./modules/kubernetes_cluster"
#   cluster_name = "${var.cluster_names[1]}"
#   bastion_private_ip = "${module.bastion.private_ip}"
#   bastion_public_ip = "${module.bastion.public_ip}"
#   bastion_security_group_id = "${module.bastion.security_group_id}"
#   key_name = "${aws_key_pair.client.key_name}"
#   public_subnet_id = "${module.vpc.public_subnet_id}"
#   private_subnet_id = "${module.vpc.private_subnet_id}"
#   worker_count = "${var.worker_count}"
#   vpc_id = "${module.vpc.vpc_id}"
#   root_domain = "${var.root_domain}"
#   domain_name = "${join(".", list(var.cluster_names[1], var.root_domain))}"
#   letsencrypt_email = "${var.letsencrypt_email}"
# }


output "bastion_ip" {
    value = "${module.bastion.public_ip}"
}

output "master_ip_a" {
    value = "${module.kubernetes_cluster_a.master_ip}"
}

output "load_balancer_a" {
    value = "${module.kubernetes_cluster_a.load_balancer}"
}

# output "master_ip_b" {
#     value = "${module.kubernetes_cluster_b.master_ip}"
# }

# output "load_balancer_b" {
#     value = "${module.kubernetes_cluster_b.load_balancer}"
# }

