provider "aws" {
    region = "us-east-2"
}

resource "aws_key_pair" "client" {
    key_name = "ter-key"
    public_key = "${file("~/.ssh/id_rsa_aws.pub")}"
}

module "vpc" {
  source = "./modules/vpc"
  cluster_name = "k8s"
  availability_zone = "us-east-2b"
}

module "bastion" {
  source = "./modules/bastion"
  vpc_id = "${module.vpc.vpc_id}"
  public_subnet_id = "${module.vpc.public_subnet_id}"
  key_name = "${aws_key_pair.client.key_name}"
  local_ip = "${var.local_ip}"
}

module "kubernetes_cluster" {
  source = "./modules/kubernetes_cluster"
  bastion_private_ip = "${module.bastion.private_ip}"
  bastion_public_ip = "${module.bastion.public_ip}"
  bastion_security_group_id = "${module.bastion.security_group_id}"
  key_name = "${aws_key_pair.client.key_name}"
  public_subnet_id = "${module.vpc.public_subnet_id}"
  private_subnet_id = "${module.vpc.private_subnet_id}"
  worker_count = "${var.worker_count}"
  vpc_id = "${module.vpc.vpc_id}"
  domain_name = "${var.domain}"
  letsencrypt_email = "${var.letsencrypt_email}"
}


output "bastion_ip" {
    value = "${module.bastion.public_ip}"
}

output "master_ip" {
    value = "${module.kubernetes_cluster.master_ip}"
}

output "load_balancer" {
    value = "${module.kubernetes_cluster.load_balancer}"
}

