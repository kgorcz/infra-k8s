provider "aws" {
    region = "us-east-2"
}

module "vpc" {
  source = "./modules/vpc"
  cluster_name = "k8s"
  availability_zone = "us-east-2b"
}


data "template_file" "bastion_cloud_config" {
    template = "${file("bastion.yml")}"
    vars {
        bootport_key = "${file("id_rsa_port.pub")}"
    }
}

data "template_cloudinit_config" "bastion_cloud_init" {
    part {
        content_type = "text/cloud-config"
        content = "${data.template_file.bastion_cloud_config.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${file("bootstrap-bastion.sh")}"
    }
}

resource "aws_instance" "bastion" {
    ami = "ami-00c5940f2b52c5d98"
    instance_type = "t2.micro"
    subnet_id = "${module.vpc.public_subnet_id}"
    vpc_security_group_ids = ["${aws_security_group.asg_public.id}"]
    key_name = "${aws_key_pair.client.key_name}"

    user_data = "${data.template_cloudinit_config.bastion_cloud_init.rendered}"

    tags {
        Name = "bastion"
    }
}

data "template_file" "join_teleport" {
    template = "${file("join-teleport.sh")}"
    vars {
        bastion_ip = "${aws_instance.bastion.private_ip}"
    }
}

data "template_file" "setup_teleport_k8s" {
    template = "${file("setup-teleport-k8s.sh")}"
    vars {
        bastion_private_ip = "${aws_instance.bastion.private_ip}"
        bastion_public_ip = "${aws_instance.bastion.public_ip}"
    }
}

data "template_file" "master_cloud_config" {
    template = "${file("master.yml")}"
    vars {
        worker_bootk8s_key = "${file("id_rsa_worker.pub")}"
        bootport_private_key_b64 = "${file("id_rsa_port.b64")}"
        bootport_public_key_b64 = "${file("id_rsa_port.pub.b64")}"
    }
}
data "template_file" "finish_bootstrap" {
    template = "${file("bootstrap-finish.sh")}"
    vars {
        letsencrypt_email = "${var.letsencrypt_email}"
        node_count = "${var.worker_count}"
    }
}

data "template_cloudinit_config" "master_cloud_init" {
    part {
        content_type = "text/cloud-config"
        content = "${data.template_file.master_cloud_config.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${file("bootstrap-master.sh")}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.join_teleport.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.setup_teleport_k8s.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.finish_bootstrap.rendered}"
    }
}

resource "aws_instance" "master_node" {
    ami = "ami-00c5940f2b52c5d98"
    instance_type = "t2.medium"
    subnet_id = "${module.vpc.private_subnet_id}"
    vpc_security_group_ids = ["${aws_security_group.asg_private.id}"]
    key_name = "${aws_key_pair.client.key_name}"
    root_block_device {
      volume_size = 16
    }

    user_data = "${data.template_cloudinit_config.master_cloud_init.rendered}"

    tags {
        Name = "tkub-master"
    }
}

data "template_file" "worker_cloud_config" {
    template = "${file("worker.yml")}"
    vars {
        worker_private_key_b64 = "${file("id_rsa_worker.b64")}"
        worker_public_key_b64 = "${file("id_rsa_worker.pub.b64")}"
        bootport_private_key_b64 = "${file("id_rsa_port.b64")}"
        bootport_public_key_b64 = "${file("id_rsa_port.pub.b64")}"
    }
}

data "template_file" "worker_bootstrap" {
    template = "${file("bootstrap-worker.sh")}"
    vars {
        master_ip = "${aws_instance.master_node.private_ip}"
    }
}

data "template_cloudinit_config" "worker_cloud_init" {
    part {
        content_type = "text/cloud-config"
        content = "${data.template_file.worker_cloud_config.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.worker_bootstrap.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${data.template_file.join_teleport.rendered}"
    }
}

resource "aws_instance" "worker_node" {
    ami = "ami-00c5940f2b52c5d98"
    instance_type = "t2.medium"
    subnet_id = "${module.vpc.private_subnet_id}"
    vpc_security_group_ids = ["${aws_security_group.asg_private.id}"]
    key_name = "${aws_key_pair.client.key_name}"
    user_data = "${data.template_cloudinit_config.worker_cloud_init.rendered}"
    root_block_device {
      volume_size = 16
    }

    count = "${var.worker_count}"

    tags {
        Name = "tkub-worker-${count.index}"
    }
}

resource "aws_key_pair" "client" {
    key_name = "ter-key"
    public_key = "${file("~/.ssh/id_rsa_aws.pub")}"
}

resource "aws_security_group" "asg_public" {
    name = "ter-asg-public"
    vpc_id = "${module.vpc.vpc_id}"
}
 
resource "aws_security_group_rule" "ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${var.local_ip}/32"]
    security_group_id = "${aws_security_group.asg_public.id}"
}

resource "aws_security_group_rule" "teleport_web" {
    type = "ingress"
    from_port = 3080
    to_port = 3080
    protocol = "tcp"
    cidr_blocks = ["${var.local_ip}/32"]
    security_group_id = "${aws_security_group.asg_public.id}"
}

resource "aws_security_group_rule" "teleport_ssh" {
    type = "ingress"
    from_port = 3023
    to_port = 3023
    protocol = "tcp"
    cidr_blocks = ["${var.local_ip}/32"]
    security_group_id = "${aws_security_group.asg_public.id}"
}

resource "aws_security_group_rule" "teleport_kubernetes" {
    type = "ingress"
    from_port = 3026
    to_port = 3026
    protocol = "tcp"
    cidr_blocks = ["${var.local_ip}/32"]
    security_group_id = "${aws_security_group.asg_public.id}"
}

resource "aws_security_group_rule" "ingress_public" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id = "${aws_security_group.asg_private.id}"
    security_group_id = "${aws_security_group.asg_public.id}"
}

resource "aws_security_group_rule" "egress_public" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.asg_public.id}"
}

resource "aws_security_group" "asg_private" {
    name = "ter-asg-private"
    vpc_id = "${module.vpc.vpc_id}"
}

resource "aws_security_group_rule" "ingress_private_from_public" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id = "${aws_security_group.asg_public.id}"
    security_group_id = "${aws_security_group.asg_private.id}"
}

resource "aws_security_group_rule" "ingress_private_from_private" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id = "${aws_security_group.asg_private.id}"
    security_group_id = "${aws_security_group.asg_private.id}"
}

resource "aws_security_group_rule" "ingress_private_to_nodeport" {
    type = "ingress"
    from_port = 32323
    to_port = 32325
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.asg_private.id}"
}

resource "aws_security_group_rule" "egress_private" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.asg_private.id}"
}

resource "aws_lb" "nlb" {
  name               = "ter-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets = ["${module.vpc.public_subnet_id}"]
  #enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = "${aws_lb.nlb.arn}"
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.http_target.arn}"
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = "${aws_lb.nlb.arn}"
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.https_target.arn}"
  }
}

resource "aws_lb_listener" "dicom_listener" {
  load_balancer_arn = "${aws_lb.nlb.arn}"
  port              = "104"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.dicom_target.arn}"
  }
}

resource "aws_lb_target_group" "http_target" {
  name     = "ter-http-target"
  port     = 32323
  protocol = "TCP"
  vpc_id   = "${module.vpc.vpc_id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_http" {
  target_group_arn = "${aws_lb_target_group.http_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = "${var.worker_count}"
}

resource "aws_lb_target_group" "https_target" {
  name     = "ter-https-target"
  port     = 32324
  protocol = "TCP"
  vpc_id   = "${module.vpc.vpc_id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_https" {
  target_group_arn = "${aws_lb_target_group.https_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = "${var.worker_count}"
}

resource "aws_lb_target_group" "dicom_target" {
  name     = "ter-dicom-target"
  port     = 32325
  protocol = "TCP"
  vpc_id   = "${module.vpc.vpc_id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_dicom" {
  target_group_arn = "${aws_lb_target_group.dicom_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = "${var.worker_count}"
}

data "aws_route53_zone" "primary" {
  name         = "${var.domain}."
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "*.${var.domain}"
  type    = "A"

  alias {
    name                   = "${aws_lb.nlb.dns_name}"
    zone_id                = "${aws_lb.nlb.zone_id}"
    evaluate_target_health = false
  }
}

output "bastion_ip" {
    value = "${aws_instance.bastion.public_ip}"
}

output "master_ip" {
    value = "${aws_instance.master_node.private_ip}"
}

output "load_balancer" {
    value = "${aws_lb.nlb.dns_name}"
}

