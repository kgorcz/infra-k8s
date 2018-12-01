provider "aws" {
    region = "us-east-2"
}

data "template_file" "master_cloud_config" {
    template = "${file("master.yml")}"
    vars {
        worker_public_key = "${file("id_rsa_worker.pub")}"
    }
}
data "template_file" "finish_bootstrap" {
    template = "${file("bootstrap-finish.sh")}"
    vars {
        letsencrypt_email = "${var.letsencrypt_email}"
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
        content = "${data.template_file.finish_bootstrap.rendered}"
    }
}

resource "aws_instance" "master_node" {
    ami = "ami-05829248ffee66250"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.public_subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.asg_public.id}"]
    key_name = "${aws_key_pair.client.key_name}"

    user_data = "${data.template_cloudinit_config.master_cloud_init.rendered}"

    tags {
        Name = "tkub-master"
    }

    depends_on = ["aws_route_table_association.public"]
}

data "template_file" "worker_cloud_config" {
    template = "${file("worker.yml")}"
    vars {
        worker_private_key = "${file("id_rsa_worker")}"
        worker_public_key = "${file("id_rsa_worker.pub")}"
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
}

resource "aws_instance" "worker_node" {
    ami = "ami-05829248ffee66250"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.private_subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.asg_private.id}"]
    key_name = "${aws_key_pair.client.key_name}"
    user_data = "${data.template_cloudinit_config.worker_cloud_init.rendered}"

    count = 2

    tags {
        Name = "tkub-worker-${count.index}"
    }

    depends_on = ["aws_route_table_association.private"]
}

resource "aws_key_pair" "client" {
    key_name = "ter-key"
    public_key = "${file("~/.ssh/id_rsa_aws.pub")}"
}

resource "aws_security_group" "asg_public" {
    name = "ter-asg-public"
    vpc_id = "${aws_vpc.main.id}"
}
 
resource "aws_security_group_rule" "ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
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
    vpc_id = "${aws_vpc.main.id}"
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

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_eip" "nat" {
  vpc = true
  depends_on = ["aws_internet_gateway.igw"]
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"
}

resource "aws_subnet" "public_subnet" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.0.0/20"
    availability_zone = "us-east-2b"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
    vpc_id = "${aws_vpc.main.id}"
    cidr_block = "10.0.16.0/20"
    availability_zone = "us-east-2b"
}

resource "aws_route_table" "route_public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table" "route_private" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ngw.id}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.route_public.id}"
}

resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.route_private.id}"
}

resource "aws_lb" "nlb" {
  name               = "ter-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets = ["${aws_subnet.public_subnet.id}"]
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
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_http" {
  target_group_arn = "${aws_lb_target_group.http_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = 2
}

resource "aws_lb_target_group" "https_target" {
  name     = "ter-https-target"
  port     = 32324
  protocol = "TCP"
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_https" {
  target_group_arn = "${aws_lb_target_group.https_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = 2
}

resource "aws_lb_target_group" "dicom_target" {
  name     = "ter-dicom-target"
  port     = 32325
  protocol = "TCP"
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_lb_target_group_attachment" "nlb_attachment_dicom" {
  target_group_arn = "${aws_lb_target_group.dicom_target.arn}"
  target_id        =  "${element(aws_instance.worker_node.*.id, count.index)}"
  count = 2
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

output "master_ip" {
    value = "${aws_instance.master_node.public_ip}"
}

output "worker_ip" {
    value = "${aws_instance.worker_node.0.private_ip}"
}

output "load_balancer" {
    value = "${aws_lb.nlb.dns_name}"
}

