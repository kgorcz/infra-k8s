
data "template_file" "bastion_cloud_config" {
    template = "${file("${path.module}/bastion.yml")}"
    vars {
        bootport_key = "${file("pki/id_rsa_port.pub")}"
    }
}

data "template_cloudinit_config" "bastion_cloud_init" {
    part {
        content_type = "text/cloud-config"
        content = "${data.template_file.bastion_cloud_config.rendered}"
    }
    part {
        content_type = "text/x-shellscript"
        content = "${file("scripts/bootstrap-bastion.sh")}"
    }
}

resource "aws_instance" "bastion" {
    ami = "ami-05bad978b2cf5d78c"
    instance_type = "t3a.micro"
    subnet_id = "${var.public_subnet_id}"
    vpc_security_group_ids = ["${aws_security_group.asg_public.id}"]
    key_name = "${var.key_name}"

    user_data = "${data.template_cloudinit_config.bastion_cloud_init.rendered}"

    tags {
        Name = "bastion"
    }
}

resource "aws_security_group" "asg_public" {
    name = "ter-asg-public"
    vpc_id = "${var.vpc_id}"
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

resource "aws_security_group_rule" "egress_public" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.asg_public.id}"
}

output "security_group_id" {
    value = "${aws_security_group.asg_public.id}"
}

output "public_ip" {
    value = "${aws_instance.bastion.public_ip}"
}

output "private_ip" {
    value = "${aws_instance.bastion.private_ip}"
}
