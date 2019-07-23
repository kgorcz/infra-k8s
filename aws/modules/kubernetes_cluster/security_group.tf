resource "aws_security_group" "asg_private" {
    name = "ter-asg-private"
    vpc_id = "${var.vpc_id}"
}

resource "aws_security_group_rule" "ingress_private_from_public" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id = "${var.bastion_security_group_id}"
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
resource "aws_security_group_rule" "ingress_public" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id = "${aws_security_group.asg_private.id}"
    security_group_id = "${var.bastion_security_group_id}"
}
